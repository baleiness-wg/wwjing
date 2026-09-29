const pool = require("../db");

const STANDARD_FOLDERS = ["默认收藏夹", "购物收藏夹", "文章收藏夹", "视频收藏夹", "代码收藏夹"];

async function ensureStandardFolders(userId) {
  await pool.query(
    `INSERT INTO folders (user_id, name)
     SELECT $1, name FROM unnest($2::text[]) AS name
     ON CONFLICT (user_id, name) DO NOTHING`,
    [userId, STANDARD_FOLDERS]
  );
}

async function findAll(userId) {
  await ensureStandardFolders(userId);
  const result = await pool.query(
    `SELECT f.id, f.name, COUNT(i.id)::int AS "itemCount"
     FROM folders f
     LEFT JOIN items i ON i.folder_id = f.id
     WHERE f.user_id = $1
     GROUP BY f.id
     ORDER BY f.created_at ASC`,
    [userId]
  );
  return result.rows;
}

async function create(userId, name) {
  const result = await pool.query(
    `INSERT INTO folders (user_id, name) VALUES ($1, $2)
     RETURNING id, name, 0::int AS "itemCount"`,
    [userId, name]
  );
  return result.rows[0];
}

async function getOrCreateDefault(userId) {
  const result = await pool.query(
    `INSERT INTO folders (user_id, name) VALUES ($1, '默认收藏夹')
     ON CONFLICT (user_id, name) DO UPDATE SET name = EXCLUDED.name
     RETURNING id, name`,
    [userId]
  );
  return result.rows[0];
}

async function findByName(userId, name) {
  await ensureStandardFolders(userId);
  const result = await pool.query(
    "SELECT id, name FROM folders WHERE user_id = $1 AND name = $2",
    [userId, name]
  );
  return result.rows[0] || null;
}

module.exports = { findAll, create, getOrCreateDefault, findByName };
