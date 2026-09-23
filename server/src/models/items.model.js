const pool = require("../db");

async function findAll(userId) {
  const result = await pool.query(
    `SELECT id, title, source_url AS "sourceUrl", next_action AS "nextAction", status
     FROM items WHERE user_id = $1 ORDER BY created_at DESC`,
    [userId]
  );

  return result.rows;
}

async function create(userId, input) {
  const result = await pool.query(
    `INSERT INTO items (user_id, title, source_url, next_action)
     VALUES ($1, $2, $3, $4)
     RETURNING id, title, source_url AS "sourceUrl", next_action AS "nextAction", status`,
    [userId, input.title, input.sourceUrl, input.nextAction]
  );

  return result.rows[0];
}

module.exports = { findAll, create };
