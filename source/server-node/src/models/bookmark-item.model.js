const pool = require("../db");
const { randomId } = require("../utils/id");

const selectFields = `id, space, folder_id AS "folderId", item_type AS "itemType", title,
  description, images, images->>0 AS "coverUrl", source_url AS "sourceUrl", normalized_url AS "normalizedUrl",
  source_host AS "sourceHost", metadata, created_at AS "createdAt", updated_at AS "updatedAt"`;

async function findById(userId, id, space = "star", client = pool) {
  const result = await client.query(
    `SELECT ${selectFields} FROM bookmark_items WHERE id = $2 AND space = $3 AND (user_id = $1 OR folder_id IN (WITH RECURSIVE shared AS (SELECT folder_id AS id FROM bookmark_folder_shares WHERE user_id = $1 AND space = $3 UNION ALL SELECT child.id FROM bookmark_folders child JOIN shared ON child.parent_id = shared.id WHERE child.space = $3) SELECT id FROM shared))`,
    [userId, id, space]
  );
  return result.rows[0] || null;
}

async function findDuplicate(userId, normalizedUrl, space = "star", client = pool) {
  const result = await client.query(
    `SELECT item.id, item.title, item.folder_id AS "folderId", folder.name AS "folderName"
     FROM bookmark_items item
     LEFT JOIN bookmark_folders folder ON folder.id = item.folder_id AND folder.user_id = item.user_id
     WHERE item.user_id = $1 AND item.normalized_url = $2 AND item.space = $3
     ORDER BY item.updated_at DESC, item.id DESC LIMIT 1`,
    [userId, normalizedUrl, space]
  );
  return result.rows[0] || null;
}

async function list(userId, filters) {
  const conditions = ["item.space = $2", "(item.user_id = $1 OR item.folder_id IN (SELECT folder_id FROM bookmark_folder_shares WHERE user_id = $1 AND space = $2))"];
  const parameters = [userId, filters.space || "star"];
  if (filters.folderId) {
    parameters.push(filters.folderId);
    if (filters.includeDescendants) {
      conditions.push(`item.folder_id IN (
        WITH RECURSIVE descendants AS (
          SELECT id FROM bookmark_folders WHERE user_id = $1 AND space = $2 AND id = $${parameters.length}
          UNION ALL
          SELECT child.id FROM bookmark_folders child JOIN descendants parent ON child.parent_id = parent.id
          WHERE child.user_id = $1 AND child.space = $2
        ) SELECT id FROM descendants
      )`);
    } else {
      conditions.push(`item.folder_id = $${parameters.length}`);
    }
  } else if (filters.uncategorized) {
    conditions.push("item.folder_id IS NULL");
  }
  if (filters.query) {
    parameters.push(`%${filters.query.replace(/[\\%_]/g, "\\$&")}%`);
    conditions.push(`(COALESCE(item.title, '') ILIKE $${parameters.length} ESCAPE '\\'
      OR COALESCE(item.description, '') ILIKE $${parameters.length} ESCAPE '\\'
      OR item.source_url ILIKE $${parameters.length} ESCAPE '\\')`);
  }
  parameters.push(filters.pageSize, (filters.page - 1) * filters.pageSize);
  const limitIndex = parameters.length - 1;
  const offsetIndex = parameters.length;
  const result = await pool.query(
    `SELECT ${selectFields}, COUNT(*) OVER()::int AS "totalCount"
     FROM bookmark_items item
     WHERE ${conditions.join(" AND ")}
     ORDER BY item.updated_at DESC, item.id DESC
     LIMIT $${limitIndex} OFFSET $${offsetIndex}`,
    parameters
  );
  return {
    items: result.rows.map(({ totalCount, ...item }) => item),
    total: result.rows[0]?.totalCount || 0
  };
}

async function create(userId, values) {
  const result = await pool.query(
     `INSERT INTO bookmark_items
          (id, user_id, space, folder_id, title, description, images, source_url, normalized_url, source_host)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
     RETURNING ${selectFields}`,
    [randomId(), userId, values.space, values.folderId, values.title, values.description, JSON.stringify(values.images || []), values.sourceUrl,
      values.normalizedUrl, values.sourceHost]
  );
  return result.rows[0];
}

async function update(userId, id, values) {
  const result = await pool.query(
      `UPDATE bookmark_items SET folder_id = $4, title = $5, description = $6,
        images = $7, source_url = $8, normalized_url = $9, source_host = $10, updated_at = NOW()
      WHERE id = $2 AND space = $3 AND (user_id = $1 OR folder_id IN (WITH RECURSIVE shared AS (SELECT folder_id AS id FROM bookmark_folder_shares WHERE user_id = $1 AND space = $3 UNION ALL SELECT child.id FROM bookmark_folders child JOIN shared ON child.parent_id = shared.id WHERE child.space = $3) SELECT id FROM shared))
     RETURNING ${selectFields}`,
    [userId, id, values.space, values.folderId, values.title, values.description, JSON.stringify(values.images || []), values.sourceUrl,
      values.normalizedUrl, values.sourceHost]
  );
  return result.rows[0] || null;
}

async function remove(userId, id, space = "star") {
  const result = await pool.query(
    "DELETE FROM bookmark_items WHERE id = $2 AND space = $3 AND (user_id = $1 OR folder_id IN (WITH RECURSIVE shared AS (SELECT folder_id AS id FROM bookmark_folder_shares WHERE user_id = $1 AND space = $3 UNION ALL SELECT child.id FROM bookmark_folders child JOIN shared ON child.parent_id = shared.id WHERE child.space = $3) SELECT id FROM shared))",
    [userId, id, space]
  );
  return result.rowCount > 0;
}

module.exports = { findById, findDuplicate, list, create, update, remove };
