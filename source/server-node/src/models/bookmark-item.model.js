const pool = require("../db");
const { randomId } = require("../utils/id");
const { signImages } = require("../services/oss.service");

const platformDomains = {
  xiaohongshu: ["xiaohongshu.com", "xhslink.cn", "xhslink.com"],
  douyin: ["douyin.com", "iesdouyin.com"],
  bilibili: ["bilibili.com", "b23.tv"]
};

const selectFields = `item.id, item.space,
  COALESCE((SELECT array_agg(link.folder_id ORDER BY link.folder_id) FROM bookmark_item_folders link WHERE link.item_id = item.id), ARRAY[]::varchar[]) AS "folderIds",
  COALESCE((SELECT link.folder_id FROM bookmark_item_folders link WHERE link.item_id = item.id ORDER BY link.folder_id LIMIT 1), item.folder_id) AS "folderId",
  item.item_type AS "itemType", item.title, item.description, item.images, item.images->>0 AS "coverUrl",
  item.source_url AS "sourceUrl", item.normalized_url AS "normalizedUrl", item.source_host AS "sourceHost",
  item.metadata, item.created_at AS "createdAt", item.updated_at AS "updatedAt"`;

const visibleFolders = (spaceParameter) => `(WITH RECURSIVE visible_folders AS (
  SELECT id FROM bookmark_folders WHERE user_id = $1 AND space = ${spaceParameter}
  UNION SELECT folder_id FROM bookmark_folder_shares WHERE user_id = $1 AND space = ${spaceParameter}
  UNION SELECT child.id FROM bookmark_folders child JOIN visible_folders parent ON child.parent_id = parent.id WHERE child.space = ${spaceParameter}
) SELECT id FROM visible_folders)`;

function itemVisibility(spaceParameter = "$2", alias = "item") {
  return `(${alias}.user_id = $1 OR EXISTS (
    SELECT 1 FROM bookmark_item_folders link
    WHERE link.item_id = ${alias}.id AND link.folder_id IN ${visibleFolders(spaceParameter)}
  ) OR (${alias}.folder_id IN ${visibleFolders(spaceParameter)}))`;
}

async function findById(userId, id, space = "star", client = pool) {
  const result = await client.query(
    `SELECT ${selectFields} FROM bookmark_items item WHERE item.id = $2 AND item.space = $3 AND ${itemVisibility("$3")}`,
    [userId, id, space]
  );
  if (!result.rows[0]) return null;
  result.rows[0].images = signImages(result.rows[0].images || []);
  result.rows[0].coverUrl = result.rows[0].images[0] || result.rows[0].coverUrl;
  return result.rows[0];
}

async function findDuplicate(userId, normalizedUrl, space = "star", client = pool) {
  const result = await client.query(
    `SELECT item.id, item.title, item.folder_id AS "folderId", folder.name AS "folderName"
     FROM bookmark_items item LEFT JOIN bookmark_folders folder ON folder.id = item.folder_id AND folder.user_id = item.user_id
     WHERE item.user_id = $1 AND item.normalized_url = $2 AND item.space = $3
     ORDER BY item.updated_at DESC, item.id DESC LIMIT 1`, [userId, normalizedUrl, space]
  );
  return result.rows[0] || null;
}

async function list(userId, filters) {
  const conditions = [`item.space = $2`, itemVisibility("$2")];
  const parameters = [userId, filters.space || "star"];
  let pinFolderParameter;
  if (filters.itemType) { parameters.push(filters.itemType); conditions.push(`item.item_type = $${parameters.length}`); }
  if (filters.excludeCompleted) conditions.push("COALESCE((item.metadata->>'completed')::boolean, false) = false");
  if (filters.folderId) {
    parameters.push(filters.folderId);
    pinFolderParameter = parameters.length;
    const folderFilter = filters.includeDescendants ? `WITH RECURSIVE descendants AS (
      SELECT id FROM bookmark_folders WHERE id = $${parameters.length} AND space = $2
      UNION ALL SELECT child.id FROM bookmark_folders child JOIN descendants parent ON child.parent_id = parent.id WHERE child.space = $2
    ) SELECT id FROM descendants` : `$${parameters.length}`;
    conditions.push(`(EXISTS (SELECT 1 FROM bookmark_item_folders link WHERE link.item_id = item.id AND link.folder_id IN (${folderFilter})) OR item.folder_id IN (${folderFilter}))`);
  } else if (filters.folderIds?.length) {
    parameters.push(filters.folderIds);
    conditions.push(`(EXISTS (SELECT 1 FROM bookmark_item_folders link WHERE link.item_id = item.id AND link.folder_id = ANY($${parameters.length}::varchar[])) OR item.folder_id = ANY($${parameters.length}::varchar[]))`);
  } else if (filters.uncategorized) {
    conditions.push("NOT EXISTS (SELECT 1 FROM bookmark_item_folders link WHERE link.item_id = item.id) AND item.folder_id IS NULL");
  }
  if (filters.query) { parameters.push(`%${filters.query.replace(/[\\%_]/g, "\\$&" )}%`); conditions.push(`(COALESCE(item.title, '') ILIKE $${parameters.length} ESCAPE '\\' OR COALESCE(item.description, '') ILIKE $${parameters.length} ESCAPE '\\' OR item.source_url ILIKE $${parameters.length} ESCAPE '\\')`); }
  if (filters.platform && filters.platform !== "all") {
    if (filters.platform === "note") {
      conditions.push("item.source_url IS NULL");
    } else {
      const domains = platformDomains[filters.platform].map((domain) => domain.replaceAll('.', '\\.'));
      parameters.push(`(^|://)([^/]+\\.)?(${domains.join('|')})([/:]|$)`);
      conditions.push(`(lower(coalesce(item.source_host, '')) ~ $${parameters.length} OR lower(coalesce(item.source_url, '')) ~ $${parameters.length})`);
    }
  }
  parameters.push(filters.pageSize, (filters.page - 1) * filters.pageSize);
  const limitIndex = parameters.length - 1;
  const offsetIndex = parameters.length;
  let pinnedExpression = "false";
  if (filters.folderId) {
    const pinnedFolderFilter = filters.includeDescendants
      ? `WITH RECURSIVE descendants AS (
           SELECT id FROM bookmark_folders WHERE id = $${pinFolderParameter} AND space = $2
           UNION ALL
           SELECT child.id FROM bookmark_folders child
           JOIN descendants parent ON child.parent_id = parent.id
           WHERE child.space = $2
         ) SELECT id FROM descendants`
      : `$${pinFolderParameter}`;
    pinnedExpression = `EXISTS (
      SELECT 1 FROM bookmark_item_folders pin
      WHERE pin.item_id = item.id
        AND pin.folder_id IN (${pinnedFolderFilter})
        AND pin.pinned = true
    )`;
  } else if (!filters.uncategorized) {
    pinnedExpression = `EXISTS (
      SELECT 1 FROM bookmark_item_folders pin
      WHERE pin.item_id = item.id AND pin.pinned = true
    )`;
  }
  const itemSelect = `${selectFields}, ${pinnedExpression} AS "pinned"`;
  const pinOrder = pinnedExpression === "false" ? "" : `${pinnedExpression} DESC,`;
  const result = await pool.query(`SELECT ${itemSelect}, COUNT(*) OVER()::int AS "totalCount" FROM bookmark_items item WHERE ${conditions.join(" AND ")} ORDER BY ${pinOrder} item.updated_at DESC, item.id DESC LIMIT $${limitIndex} OFFSET $${offsetIndex}`, parameters);
  return { items: result.rows.map(({ totalCount, ...item }) => ({ ...item, images: signImages(item.images || []) })), total: result.rows[0]?.totalCount || 0 };
}

async function syncFolders(client, itemId, userId, space, folderIds) {
  const existing = await client.query(
    "SELECT folder_id, pinned FROM bookmark_item_folders WHERE item_id = $1",
    [itemId]
  );
  const pinnedByFolder = new Map(existing.rows.map((row) => [String(row.folder_id), row.pinned]));
  await client.query("DELETE FROM bookmark_item_folders WHERE item_id = $1", [itemId]);
  if (folderIds.length) {
    await client.query(
      `INSERT INTO bookmark_item_folders (item_id, folder_id, pinned)
       SELECT $1, folder.id, COALESCE(($3::jsonb ->> folder.id)::boolean, false)
       FROM bookmark_folders folder
       WHERE folder.id = ANY($2::varchar[])`,
      [itemId, folderIds, JSON.stringify(Object.fromEntries(pinnedByFolder))]
    );
  }
}

async function create(userId, values) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const id = randomId();
    await client.query(`INSERT INTO bookmark_items (id, user_id, space, folder_id, item_type, title, description, images, source_url, normalized_url, source_host, metadata) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)`, [id, userId, values.space, values.folderIds[0] || null, values.itemType || "link", values.title, values.description, JSON.stringify(values.images || []), values.sourceUrl, values.normalizedUrl, values.sourceHost, JSON.stringify(values.metadata || {})]);
    await syncFolders(client, id, userId, values.space, values.folderIds);
    await client.query("COMMIT");
    return await findById(userId, id, values.space);
  } catch (error) { await client.query("ROLLBACK"); throw error; } finally { client.release(); }
}

async function update(userId, id, values) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await client.query(`UPDATE bookmark_items item SET folder_id = $4, title = $5, description = $6, images = $7, source_url = $8, normalized_url = $9, source_host = $10, metadata = $11, updated_at = NOW() WHERE item.id = $2 AND item.space = $3 AND ${itemVisibility("$3")} RETURNING item.id`, [userId, id, values.space, values.folderIds[0] || null, values.title, values.description, JSON.stringify(values.images || []), values.sourceUrl, values.normalizedUrl, values.sourceHost, JSON.stringify(values.metadata || {})]);
    if (!result.rows[0]) { await client.query("ROLLBACK"); return null; }
    await syncFolders(client, id, userId, values.space, values.folderIds);
    await client.query("COMMIT");
    return await findById(userId, id, values.space);
  } catch (error) { await client.query("ROLLBACK"); throw error; } finally { client.release(); }
}

async function remove(userId, id, space = "star") {
  const result = await pool.query(`DELETE FROM bookmark_items item WHERE item.id = $2 AND item.space = $3 AND ${itemVisibility("$3")}`, [userId, id, space]);
  return result.rowCount > 0;
}

async function pin(userId, itemId, folderId, pinned, space) {
  if (!folderId) {
    await pool.query(
      `UPDATE bookmark_item_folders link SET pinned = $3
       FROM bookmark_items item
       WHERE link.item_id = $2 AND item.id = link.item_id AND item.user_id = $1 AND item.space = $4`,
      [userId, itemId, pinned, space]
    );
    await pool.query("UPDATE bookmark_items SET updated_at = NOW() WHERE id = $1 AND user_id = $2 AND space = $3", [itemId, userId, space]);
    return true;
  }
  const result = await pool.query(
    `UPDATE bookmark_item_folders link SET pinned = $4
     FROM bookmark_items item
     WHERE link.item_id = $2 AND link.folder_id = $3 AND item.id = link.item_id
       AND item.user_id = $1 AND item.space = $5`,
    [userId, itemId, folderId, pinned, space]
  );
  if (result.rowCount > 0) {
    await pool.query("UPDATE bookmark_items SET updated_at = NOW() WHERE id = $1 AND user_id = $2 AND space = $3", [itemId, userId, space]);
  }
  return result.rowCount > 0;
}

async function findItemsMissingImages(limit = 100) {
  const result = await pool.query(
    `SELECT id, user_id AS "userId", source_url AS "sourceUrl"
     FROM bookmark_items
     WHERE source_url IS NOT NULL
       AND btrim(source_url) <> ''
       AND (images IS NULL OR images = '[]'::jsonb)
     ORDER BY updated_at ASC, id ASC
     LIMIT $1`,
    [limit]
  );
  return result.rows;
}

async function findItemsWithImages(limit = 100) {
  const result = await pool.query(
    `SELECT id, source_url AS "sourceUrl", images
     FROM bookmark_items
     WHERE source_url IS NOT NULL AND btrim(source_url) <> ''
       AND jsonb_array_length(images) > 0
     ORDER BY updated_at ASC, id ASC LIMIT $1`,
    [limit]
  );
  return result.rows;
}

async function updateImages(id, images) {
  await pool.query(
    `UPDATE bookmark_items SET images = $2::jsonb, updated_at = NOW()
     WHERE id = $1`,
    [id, JSON.stringify(images)]
  );
}

module.exports = { findById, findDuplicate, list, create, update, remove, pin, findItemsMissingImages, findItemsWithImages, updateImages };
