CREATE TABLE IF NOT EXISTS transfer_contents (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  content_type VARCHAR(10) NOT NULL CHECK (content_type IN ('text', 'file')),
  payload BYTEA NOT NULL,
  file_name TEXT,
  mime_type TEXT,
  file_size BIGINT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT transfer_contents_file_metadata_check CHECK (
    (content_type = 'text' AND file_name IS NULL AND mime_type IS NULL AND file_size IS NULL)
    OR
    (content_type = 'file' AND file_name IS NOT NULL AND mime_type IS NOT NULL AND file_size IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS transfer_contents_user_id_idx ON transfer_contents(user_id);
