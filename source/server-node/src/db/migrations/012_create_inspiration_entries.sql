CREATE TABLE IF NOT EXISTS inspiration_entries (
  id CHAR(32) PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  space VARCHAR(20) NOT NULL CHECK (space IN ('star', 'kitchen')),
  folder_id BIGINT,
  title VARCHAR(200),
  content TEXT NOT NULL CHECK (char_length(btrim(content)) > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT inspiration_entries_folder_owner_fk
    FOREIGN KEY (folder_id, user_id)
    REFERENCES bookmark_folders(id, user_id)
    ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS inspiration_entries_page_idx
  ON inspiration_entries(user_id, space, updated_at DESC, id DESC);
