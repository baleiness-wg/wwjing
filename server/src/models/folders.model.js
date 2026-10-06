const pool = require("../db");

async function findAll(userId) {
  const result = await pool.query(
    `SELECT f.id, f.name, COUNT(i.id)::int AS "itemCount"
     FROM folders f
     LEFT JOIN favorite_details i ON i.folder_id = f.id
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
  const result = await pool.query(
    "SELECT id, name FROM folders WHERE user_id = $1 AND name = $2",
    [userId, name]
  );
  return result.rows[0] || null;
}

module.exports = { findAll, create, getOrCreateDefault, findByName };
