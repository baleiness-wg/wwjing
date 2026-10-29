ALTER TABLE bookmark_folders
  ADD COLUMN IF NOT EXISTS space VARCHAR(20) NOT NULL DEFAULT 'star';

ALTER TABLE bookmark_items
  ADD COLUMN IF NOT EXISTS space VARCHAR(20) NOT NULL DEFAULT 'star';

ALTER TABLE bookmark_folders
  DROP CONSTRAINT IF EXISTS bookmark_folders_space_check;
ALTER TABLE bookmark_folders
  ADD CONSTRAINT bookmark_folders_space_check CHECK (space IN ('star', 'cookie'));

ALTER TABLE bookmark_items
  DROP CONSTRAINT IF EXISTS bookmark_items_space_check;
ALTER TABLE bookmark_items
  ADD CONSTRAINT bookmark_items_space_check CHECK (space IN ('star', 'cookie'));

CREATE INDEX IF NOT EXISTS bookmark_folders_space_tree_idx
  ON bookmark_folders(user_id, space, parent_id, position, name, id);
CREATE INDEX IF NOT EXISTS bookmark_items_space_page_idx
  ON bookmark_items(user_id, space, updated_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS bookmark_items_space_folder_idx
  ON bookmark_items(user_id, space, folder_id, updated_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS bookmark_items_space_normalized_url_idx
  ON bookmark_items(user_id, space, normalized_url);
