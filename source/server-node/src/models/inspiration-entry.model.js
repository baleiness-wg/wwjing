const pool = require("../db");
const { randomId } = require("../utils/id");

const fields = `id, space, folder_id AS "folderId", title, content,
  created_at AS "createdAt", updated_at AS "updatedAt"`;

async function list(userId, space) {
  const result = await pool.query(
    `SELECT ${fields} FROM inspiration_entries
     WHERE user_id = $1 AND space = $2
     ORDER BY updated_at DESC, id DESC`,
    [userId, space]
  );
  return result.rows;
}

async function create(userId, values) {
  const result = await pool.query(
    `INSERT INTO inspiration_entries
      (id, user_id, space, folder_id, title, content)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING ${fields}`,
    [randomId(), userId, values.space, values.folderId, values.title, values.content]
  );
  return result.rows[0];
}

async function update(userId, id, values) {
  const result = await pool.query(
    `UPDATE inspiration_entries SET folder_id = $4, title = $5,
      content = $6, updated_at = NOW()
     WHERE id = $2 AND user_id = $1 AND space = $3
     RETURNING ${fields}`,
    [userId, id, values.space, values.folderId, values.title, values.content]
  );
  return result.rows[0] || null;
}

async function remove(userId, id, space) {
  const result = await pool.query(
    "DELETE FROM inspiration_entries WHERE id = $2 AND user_id = $1 AND space = $3",
    [userId, id, space]
  );
  return result.rowCount > 0;
}

module.exports = { list, create, update, remove };
