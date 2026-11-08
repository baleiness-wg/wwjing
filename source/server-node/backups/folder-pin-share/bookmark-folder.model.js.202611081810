const pool = require("../db");
const { randomId } = require("../utils/id");

const selectFields = `id, space, parent_id AS "parentId", name, position, pinned,
  created_at AS "createdAt", updated_at AS "updatedAt"`;

async function listByUser(userId, space = "star") {
  const result = await pool.query(
      `WITH RECURSIVE shared AS (
        SELECT folder_id AS id FROM bookmark_folder_shares WHERE user_id = $1 AND space = $2
        UNION ALL
        SELECT child.id FROM bookmark_folders child JOIN shared ON child.parent_id = shared.id
         WHERE child.space = $2
      )
      SELECT ${selectFields}
      FROM bookmark_folders
       WHERE space = $2 AND (user_id = $1 OR id IN (SELECT id FROM shared))
      ORDER BY pinned DESC, parent_id NULLS FIRST, position, name, id`,
    [userId, space]
  );
  return result.rows;
}

async function findById(userId, id, space = "star", client = pool, forUpdate = false) {
  const result = await client.query(
    `SELECT ${selectFields}
     FROM bookmark_folders
      WHERE id = $2 AND space = $3 AND (user_id = $1 OR id IN (WITH RECURSIVE shared AS (SELECT folder_id AS id FROM bookmark_folder_shares WHERE user_id = $1 AND space = $3 UNION ALL SELECT child.id FROM bookmark_folders child JOIN shared ON child.parent_id = shared.id WHERE child.space = $3) SELECT id FROM shared))${forUpdate ? " FOR UPDATE" : ""}`,
    [userId, id, space]
  );
  return result.rows[0] || null;
}

async function create(userId, values, space = "star", client = pool) {
  const result = await client.query(
    `INSERT INTO bookmark_folders (id, user_id, space, parent_id, name, position)
      VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING ${selectFields}`,
    [randomId(), userId, space, values.parentId, values.name, values.position]
  );
  return result.rows[0];
}

async function update(userId, id, values, space = "star", client = pool) {
  const result = await client.query(
    `UPDATE bookmark_folders
      SET parent_id = $4, name = $5, position = $6, pinned = $7, updated_at = NOW()
      WHERE id = $2 AND space = $3 AND (user_id = $1 OR id IN (SELECT folder_id FROM bookmark_folder_shares WHERE user_id = $1 AND space = $3))
     RETURNING ${selectFields}`,
    [userId, id, space, values.parentId, values.name, values.position, values.pinned === true]
  );
  return result.rows[0] || null;
}

async function getDepth(userId, id, space = "star", client = pool) {
  const result = await client.query(
    `WITH RECURSIVE ancestors AS (
       SELECT id, parent_id, 1 AS depth
        FROM bookmark_folders WHERE user_id = $1 AND id = $2 AND space = $3
       UNION ALL
       SELECT parent.id, parent.parent_id, ancestors.depth + 1
       FROM bookmark_folders parent
       JOIN ancestors ON parent.id = ancestors.parent_id
        WHERE parent.user_id = $1 AND parent.space = $3
     )
     SELECT COALESCE(MAX(depth), 0)::int AS depth FROM ancestors`,
    [userId, id, space]
  );
  return result.rows[0].depth;
}

async function getSubtreeDepth(userId, id, space = "star", client = pool) {
  const result = await client.query(
    `WITH RECURSIVE descendants AS (
        SELECT id, 1 AS depth FROM bookmark_folders WHERE user_id = $1 AND id = $2 AND space = $3
       UNION ALL
       SELECT child.id, descendants.depth + 1
       FROM bookmark_folders child
       JOIN descendants ON child.parent_id = descendants.id
        WHERE child.user_id = $1 AND child.space = $3
     )
     SELECT COALESCE(MAX(depth), 0)::int AS depth FROM descendants`,
    [userId, id, space]
  );
  return result.rows[0].depth;
}

async function isDescendant(userId, id, possibleDescendantId, space = "star", client = pool) {
  const result = await client.query(
    `WITH RECURSIVE descendants AS (
        SELECT id FROM bookmark_folders WHERE user_id = $1 AND parent_id = $2 AND space = $4
       UNION ALL
       SELECT child.id FROM bookmark_folders child
       JOIN descendants ON child.parent_id = descendants.id
        WHERE child.user_id = $1 AND child.space = $4
     )
     SELECT 1 FROM descendants WHERE id = $3 LIMIT 1`,
    [userId, id, possibleDescendantId, space]
  );
  return result.rowCount > 0;
}

async function hasContents(userId, id, space = "star", client = pool) {
  const result = await client.query(
    `SELECT EXISTS (
        SELECT 1 FROM bookmark_folders WHERE user_id = $1 AND parent_id = $2 AND space = $3
       UNION ALL
        SELECT 1 FROM bookmark_items WHERE user_id = $1 AND folder_id = $2 AND space = $3
     ) AS "hasContents"`,
    [userId, id, space]
  );
  return result.rows[0].hasContents;
}

async function remove(userId, id, space = "star", client = pool) {
  const result = await client.query(
    "DELETE FROM bookmark_folders WHERE user_id = $1 AND id = $2 AND space = $3",
    [userId, id, space]
  );
  return result.rowCount > 0;
}

async function share(userId, id, username, space = "star") {
  const result = await pool.query(
    `INSERT INTO bookmark_folder_shares (folder_id, owner_id, user_id, space)
     SELECT folder.id, folder.user_id, target.id, folder.space
     FROM bookmark_folders folder CROSS JOIN users target
     WHERE folder.id = $1 AND folder.user_id = $2 AND folder.space = $4 AND target.username = $3
     ON CONFLICT (folder_id, user_id) DO NOTHING
     RETURNING user_id AS "userId"`, [id, userId, username, space]
  );
  return result.rows[0] || null;
}

async function unshare(userId, id, targetUserId, space = "star") {
  const result = await pool.query(
    `DELETE FROM bookmark_folder_shares
     WHERE folder_id = $1 AND owner_id = $2 AND user_id = $3 AND space = $4`,
    [id, userId, targetUserId, space]
  );
  return result.rowCount > 0;
}

async function listShares(userId, id, space = "star") {
  const result = await pool.query(
    `SELECT shares.user_id AS "userId", users.username
     FROM bookmark_folder_shares shares JOIN users ON users.id = shares.user_id
     WHERE shares.folder_id = $1 AND shares.owner_id = $2 AND shares.space = $3
     ORDER BY users.username`, [id, userId, space]
  );
  return result.rows;
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
  remove, share, unshare, listShares
};
