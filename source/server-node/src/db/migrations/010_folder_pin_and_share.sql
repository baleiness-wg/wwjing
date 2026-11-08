ALTER TABLE bookmark_folders
  ADD COLUMN IF NOT EXISTS pinned BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS bookmark_folder_shares (
  folder_id VARCHAR(32) NOT NULL REFERENCES bookmark_folders(id) ON DELETE CASCADE,
  owner_id VARCHAR(32) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_id VARCHAR(32) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  space VARCHAR(20) NOT NULL CHECK (space IN ('star', 'cookie')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (folder_id, user_id),
  CONSTRAINT bookmark_folder_shares_not_owner CHECK (owner_id <> user_id)
);

CREATE INDEX IF NOT EXISTS bookmark_folder_shares_user_idx
  ON bookmark_folder_shares(user_id, space, folder_id);
