const pool = require("../db");

const selectFields = `id, parent_id AS "parentId", name, position,
  created_at AS "createdAt", updated_at AS "updatedAt"`;

async function listByUser(userId) {
  const result = await pool.query(
    `SELECT ${selectFields}
     FROM bookmark_folders
     WHERE user_id = $1
     ORDER BY parent_id NULLS FIRST, position, name, id`,
    [userId]
  );
  return result.rows;
}

async function findById(userId, id, client = pool, forUpdate = false) {
  const result = await client.query(
    `SELECT ${selectFields}
     FROM bookmark_folders
     WHERE user_id = $1 AND id = $2${forUpdate ? " FOR UPDATE" : ""}`,
    [userId, id]
  );
  return result.rows[0] || null;
}

async function create(userId, values, client = pool) {
  const result = await client.query(
    `INSERT INTO bookmark_folders (user_id, parent_id, name, position)
     VALUES ($1, $2, $3, $4)
     RETURNING ${selectFields}`,
    [userId, values.parentId, values.name, values.position]
  );
  return result.rows[0];
}

async function update(userId, id, values, client = pool) {
  const result = await client.query(
    `UPDATE bookmark_folders
     SET parent_id = $3, name = $4, position = $5, updated_at = NOW()
     WHERE user_id = $1 AND id = $2
     RETURNING ${selectFields}`,
    [userId, id, values.parentId, values.name, values.position]
  );
  return result.rows[0] || null;
}

async function getDepth(userId, id, client = pool) {
  const result = await client.query(
    `WITH RECURSIVE ancestors AS (
       SELECT id, parent_id, 1 AS depth
       FROM bookmark_folders WHERE user_id = $1 AND id = $2
       UNION ALL
       SELECT parent.id, parent.parent_id, ancestors.depth + 1
       FROM bookmark_folders parent
       JOIN ancestors ON parent.id = ancestors.parent_id
       WHERE parent.user_id = $1
     )
     SELECT COALESCE(MAX(depth), 0)::int AS depth FROM ancestors`,
    [userId, id]
  );
  return result.rows[0].depth;
}

async function getSubtreeDepth(userId, id, client = pool) {
  const result = await client.query(
    `WITH RECURSIVE descendants AS (
       SELECT id, 1 AS depth FROM bookmark_folders WHERE user_id = $1 AND id = $2
       UNION ALL
       SELECT child.id, descendants.depth + 1
       FROM bookmark_folders child
       JOIN descendants ON child.parent_id = descendants.id
       WHERE child.user_id = $1
     )
     SELECT COALESCE(MAX(depth), 0)::int AS depth FROM descendants`,
    [userId, id]
  );
  return result.rows[0].depth;
}

async function isDescendant(userId, id, possibleDescendantId, client = pool) {
  const result = await client.query(
    `WITH RECURSIVE descendants AS (
       SELECT id FROM bookmark_folders WHERE user_id = $1 AND parent_id = $2
       UNION ALL
       SELECT child.id FROM bookmark_folders child
       JOIN descendants ON child.parent_id = descendants.id
       WHERE child.user_id = $1
     )
     SELECT 1 FROM descendants WHERE id = $3 LIMIT 1`,
    [userId, id, possibleDescendantId]
  );
  return result.rowCount > 0;
}

async function hasContents(userId, id, client = pool) {
  const result = await client.query(
    `SELECT EXISTS (
       SELECT 1 FROM bookmark_folders WHERE user_id = $1 AND parent_id = $2
       UNION ALL
       SELECT 1 FROM bookmark_items WHERE user_id = $1 AND folder_id = $2
     ) AS "hasContents"`,
    [userId, id]
  );
  return result.rows[0].hasContents;
}

async function remove(userId, id, client = pool) {
  const result = await client.query(
    "DELETE FROM bookmark_folders WHERE user_id = $1 AND id = $2",
    [userId, id]
  );
  return result.rowCount > 0;
}

module.exports = {
  pool,
  listByUser,
  findById,
  create,
  update,
  getDepth,
  getSubtreeDepth,
  isDescendant,
  hasContents,
  remove
};
