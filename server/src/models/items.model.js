const pool = require("../db");

async function findAll(userId, folderId = null) {
  const result = await pool.query(
    `SELECT id, title, source_url AS "sourceUrl", next_action AS "nextAction", category, status, folder_id AS "folderId"
     FROM items WHERE user_id = $1 AND ($2::bigint IS NULL OR folder_id = $2) ORDER BY created_at DESC`,
    [userId, folderId]
  );

  return result.rows;
}

async function create(userId, input) {
  const result = await pool.query(
    `INSERT INTO items (user_id, title, source_url, next_action, category, folder_id)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id, title, source_url AS "sourceUrl", next_action AS "nextAction", category, status, folder_id AS "folderId"`,
    [userId, input.title, input.sourceUrl, input.nextAction, input.category, input.folderId]
  );

  return result.rows[0];
}

module.exports = { findAll, create };
