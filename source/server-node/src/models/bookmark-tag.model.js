const pool = require("../db");

const fields = `id, space, name, created_at AS "createdAt", updated_at AS "updatedAt"`;

async function list(userId, space) {
  const result = await pool.query(`SELECT ${fields} FROM bookmark_tags WHERE user_id = $1 AND space = $2 ORDER BY name, id`, [userId, space]);
  return result.rows;
}

async function findById(userId, id, space, client = pool) {
  const result = await client.query(`SELECT ${fields} FROM bookmark_tags WHERE user_id = $1 AND id = $2 AND space = $3`, [userId, id, space]);
  return result.rows[0] || null;
}

async function create(userId, space, name) {
  const result = await pool.query(`INSERT INTO bookmark_tags (user_id, space, name) VALUES ($1, $2, $3) RETURNING ${fields}`, [userId, space, name]);
  return result.rows[0];
}

async function update(userId, id, space, name) {
  const result = await pool.query(`UPDATE bookmark_tags SET name = $4, updated_at = NOW() WHERE user_id = $1 AND id = $2 AND space = $3 RETURNING ${fields}`, [userId, id, space, name]);
  return result.rows[0] || null;
}

async function remove(userId, id, space) {
  const result = await pool.query("DELETE FROM bookmark_tags WHERE user_id = $1 AND id = $2 AND space = $3", [userId, id, space]);
  return result.rowCount > 0;
}

async function replaceItemTags(userId, itemId, space, tagIds, client = pool) {
  await client.query("DELETE FROM bookmark_item_tags WHERE item_id = $1", [itemId]);
  if (!tagIds.length) return;
  await client.query(`INSERT INTO bookmark_item_tags (item_id, tag_id) SELECT $1, id FROM bookmark_tags WHERE user_id = $2 AND space = $3 AND id = ANY($4::bigint[])`, [itemId, userId, space, tagIds]);
}

module.exports = { pool, list, findById, create, update, remove, replaceItemTags };
