const pool = require("../db");
const BookmarkError = require("./bookmark-errors");

async function random(userId, input = {}) {
  if (input.space !== "cookie") throw new BookmarkError(400, "INVALID_SPACE", "随机菜谱只支持 cookie 空间");
  const parameters = [userId, "cookie"];
  const conditions = ["item.user_id = $1", "item.space = $2"];

  if (input.folderIds) {
    const rawIds = Array.isArray(input.folderIds)
      ? input.folderIds
      : String(input.folderIds).split(",").map((s) => s.trim()).filter(Boolean);
    if (rawIds.length > 0) {
      parameters.push(rawIds);
      conditions.push(`item.folder_id = ANY($${parameters.length}::bigint[])`);
    }
  } else if (input.folderId) {
    parameters.push(input.folderId);
    conditions.push(`item.folder_id = $${parameters.length}`);
  }
  if (input.tagId) {
    parameters.push(input.tagId);
    conditions.push(`EXISTS (SELECT 1 FROM bookmark_item_tags item_tag WHERE item_tag.item_id = item.id AND item_tag.tag_id = $${parameters.length})`);
  }
  const result = await pool.query(
    `SELECT item.id, item.space, item.folder_id AS "folderId", item.title, item.description,
      item.cover_url AS "coverUrl", item.source_url AS "sourceUrl", item.source_host AS "sourceHost"
     FROM bookmark_items item WHERE ${conditions.join(" AND ")} ORDER BY RANDOM() LIMIT 1`,
    parameters
  );
  return result.rows[0] || null;
}

module.exports = { random };
