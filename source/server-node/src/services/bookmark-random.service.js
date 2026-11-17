const pool = require("../db");
const BookmarkError = require("./bookmark-errors");

async function random(userId, input = {}) {
  const space = input.space || "star";
  if (!['star', 'kitchen'].includes(space)) throw new BookmarkError(400, "INVALID_SPACE", "space 必须是 star 或 kitchen");
  const parameters = [userId, space];
  const conditions = ["item.space = $2", `(item.user_id = $1 OR item.folder_id IN (
    WITH RECURSIVE visible_folders AS (
      SELECT id FROM bookmark_folders WHERE user_id = $1 AND space = $2
      UNION
      SELECT folder_id FROM bookmark_folder_shares WHERE user_id = $1 AND space = $2
      UNION
      SELECT child.id FROM bookmark_folders child JOIN visible_folders parent ON child.parent_id = parent.id
      WHERE child.space = $2
    ) SELECT id FROM visible_folders
  ))`];

  if (input.folderIds) {
    const rawIds = Array.isArray(input.folderIds)
      ? input.folderIds
      : String(input.folderIds).split(",").map((s) => s.trim()).filter(Boolean);
    if (rawIds.length > 0) {
      parameters.push(rawIds);
      conditions.push(`item.folder_id IN (WITH RECURSIVE selected AS (
        SELECT id FROM bookmark_folders WHERE id = ANY($${parameters.length}::varchar[]) AND space = $2
        UNION ALL SELECT child.id FROM bookmark_folders child JOIN selected parent ON child.parent_id = parent.id WHERE child.space = $2
      ) SELECT id FROM selected)`);
    }
  } else if (input.folderId) {
    parameters.push(input.folderId);
    conditions.push(`item.folder_id = $${parameters.length}`);
  }
  if (input.uncategorized === true || input.uncategorized === "true") {
    conditions.push("item.folder_id IS NULL");
  }
  const result = await pool.query(
     `SELECT item.id, item.space, item.folder_id AS "folderId", item.title, item.description,
      item.images, item.images->>0 AS "coverUrl", item.source_url AS "sourceUrl", item.source_host AS "sourceHost"
     FROM bookmark_items item WHERE ${conditions.join(" AND ")} ORDER BY RANDOM() LIMIT 1`,
    parameters
  );
  return result.rows[0] || null;
}

module.exports = { random };
