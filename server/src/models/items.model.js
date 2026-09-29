const pool = require("../db");

async function findAll(userId) {
  const result = await pool.query(
    `SELECT id, title, source_url AS "sourceUrl", next_action AS "nextAction", category, status
     FROM items WHERE user_id = $1 ORDER BY created_at DESC`,
    [userId]
  );

  return result.rows;
}

async function create(userId, input) {
  const result = await pool.query(
    `INSERT INTO items (user_id, title, source_url, next_action, category)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id, title, source_url AS "sourceUrl", next_action AS "nextAction", category, status`,
    [userId, input.title, input.sourceUrl, input.nextAction, input.category]
  );

  return result.rows[0];
}

module.exports = { findAll, create };
