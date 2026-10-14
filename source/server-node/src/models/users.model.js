const pool = require("../db");

async function findByUsername(username) {
  const result = await pool.query(
    "SELECT id, username, password_hash AS \"passwordHash\" FROM users WHERE username = $1",
    [username]
  );

  return result.rows[0] || null;
}

async function create({ username, passwordHash }) {
  const result = await pool.query(
    `INSERT INTO users (username, password_hash)
     VALUES ($1, $2)
     RETURNING id, username`,
    [username, passwordHash]
  );

  return result.rows[0];
}

module.exports = { findByUsername, create };
