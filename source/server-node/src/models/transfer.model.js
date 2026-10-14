const pool = require("../db");

async function findByUserId(userId) {
  const result = await pool.query(
    `SELECT content_type AS "contentType", payload, file_name AS "fileName",
            mime_type AS "mimeType", file_size AS "fileSize", updated_at AS "updatedAt"
     FROM transfer_contents WHERE user_id = $1`,
    [userId]
  );
  return result.rows[0] || null;
}

async function upsertText(userId, text) {
  await pool.query(
    `INSERT INTO transfer_contents (user_id, content_type, payload)
     VALUES ($1, 'text', $2)
     ON CONFLICT (user_id) DO UPDATE SET
       content_type = 'text', payload = EXCLUDED.payload,
       file_name = NULL, mime_type = NULL, file_size = NULL, updated_at = NOW()`,
    [userId, Buffer.from(text, "utf8")]
  );
}

async function upsertFile(userId, file) {
  await pool.query(
    `INSERT INTO transfer_contents (user_id, content_type, payload, file_name, mime_type, file_size)
     VALUES ($1, 'file', $2, $3, $4, $5)
     ON CONFLICT (user_id) DO UPDATE SET
       content_type = 'file', payload = EXCLUDED.payload,
       file_name = EXCLUDED.file_name, mime_type = EXCLUDED.mime_type,
       file_size = EXCLUDED.file_size, updated_at = NOW()`,
    [userId, file.buffer, file.originalname, file.mimetype || "application/octet-stream", file.size]
  );
}

module.exports = { findByUserId, upsertText, upsertFile };
