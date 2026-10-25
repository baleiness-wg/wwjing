CREATE TABLE IF NOT EXISTS bookmark_folders (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  parent_id BIGINT,
  name VARCHAR(120) NOT NULL CHECK (char_length(btrim(name)) > 0),
  position INTEGER NOT NULL DEFAULT 0 CHECK (position >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT bookmark_folders_id_user_unique UNIQUE (id, user_id),
  CONSTRAINT bookmark_folders_parent_not_self CHECK (parent_id IS NULL OR parent_id <> id),
  CONSTRAINT bookmark_folders_parent_owner_fk
    FOREIGN KEY (parent_id, user_id)
    REFERENCES bookmark_folders(id, user_id)
    ON DELETE RESTRICT
    DEFERRABLE INITIALLY IMMEDIATE
);

CREATE TABLE IF NOT EXISTS bookmark_items (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  folder_id BIGINT,
  item_type VARCHAR(20) NOT NULL DEFAULT 'link' CHECK (item_type = 'link'),
  title TEXT,
  description TEXT,
  source_url TEXT NOT NULL,
  normalized_url TEXT NOT NULL,
  source_host TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(metadata) = 'object'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT bookmark_items_folder_owner_fk
    FOREIGN KEY (folder_id, user_id)
    REFERENCES bookmark_folders(id, user_id)
    ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS bookmark_folders_tree_idx
  ON bookmark_folders(user_id, parent_id, position, name, id);
CREATE INDEX IF NOT EXISTS bookmark_items_page_idx
  ON bookmark_items(user_id, updated_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS bookmark_items_folder_page_idx
  ON bookmark_items(user_id, folder_id, updated_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS bookmark_items_normalized_url_idx
  ON bookmark_items(user_id, normalized_url);
