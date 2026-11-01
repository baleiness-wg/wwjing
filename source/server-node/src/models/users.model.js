const pool = require("../db");
const { randomId } = require("../utils/id");

async function findByUsername(username) {
  const result = await pool.query(
    "SELECT id, username, password_hash AS \"passwordHash\" FROM users WHERE username = $1",
    [username]
  );

  return result.rows[0] || null;
}

async function findById(id) {
  const result = await pool.query(
    "SELECT id, username, password_hash AS \"passwordHash\" FROM users WHERE id = $1",
    [id]
  );
  return result.rows[0] || null;
}

async function create({ username, passwordHash }) {
  const result = await pool.query(
     `INSERT INTO users (id, username, password_hash)
      VALUES ($1, $2, $3)
     RETURNING id, username`,
     [randomId(), username, passwordHash]
  );

  return result.rows[0];
}

async function updatePassword(id, passwordHash) {
  await pool.query(
    "UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2",
    [passwordHash, id]
  );
}

module.exports = { findByUsername, findById, create, updatePassword };
