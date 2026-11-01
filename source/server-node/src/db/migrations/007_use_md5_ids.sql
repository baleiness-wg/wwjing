-- 将已有数字 ID 转换为随机 MD5 字符串，同时保持所有关联关系。
ALTER TABLE transfer_contents DROP CONSTRAINT IF EXISTS transfer_contents_user_id_fkey;
ALTER TABLE bookmark_folders DROP CONSTRAINT IF EXISTS bookmark_folders_user_id_fkey;
ALTER TABLE bookmark_folders DROP CONSTRAINT IF EXISTS bookmark_folders_parent_owner_fk;
ALTER TABLE bookmark_items DROP CONSTRAINT IF EXISTS bookmark_items_user_id_fkey;
ALTER TABLE bookmark_items DROP CONSTRAINT IF EXISTS bookmark_items_folder_owner_fk;
ALTER TABLE bookmark_tags DROP CONSTRAINT IF EXISTS bookmark_tags_user_id_fkey;
ALTER TABLE bookmark_item_tags DROP CONSTRAINT IF EXISTS bookmark_item_tags_item_id_fkey;
ALTER TABLE bookmark_item_tags DROP CONSTRAINT IF EXISTS bookmark_item_tags_tag_id_fkey;
ALTER TABLE bookmark_folders DROP CONSTRAINT IF EXISTS bookmark_folders_parent_not_self;

ALTER TABLE users ALTER COLUMN id DROP DEFAULT;
ALTER TABLE transfer_contents ALTER COLUMN id DROP DEFAULT;
ALTER TABLE bookmark_folders ALTER COLUMN id DROP DEFAULT;
ALTER TABLE bookmark_items ALTER COLUMN id DROP DEFAULT;
ALTER TABLE bookmark_tags ALTER COLUMN id DROP DEFAULT;

ALTER TABLE users ALTER COLUMN id TYPE VARCHAR(32) USING md5(id::text);
ALTER TABLE transfer_contents ALTER COLUMN id TYPE VARCHAR(32) USING md5(id::text);
ALTER TABLE transfer_contents ALTER COLUMN user_id TYPE VARCHAR(32) USING md5(user_id::text);
ALTER TABLE bookmark_folders ALTER COLUMN id TYPE VARCHAR(32) USING md5(id::text);
ALTER TABLE bookmark_folders ALTER COLUMN user_id TYPE VARCHAR(32) USING md5(user_id::text);
ALTER TABLE bookmark_folders ALTER COLUMN parent_id TYPE VARCHAR(32) USING CASE WHEN parent_id IS NULL THEN NULL ELSE md5(parent_id::text) END;
ALTER TABLE bookmark_items ALTER COLUMN id TYPE VARCHAR(32) USING md5(id::text);
ALTER TABLE bookmark_items ALTER COLUMN user_id TYPE VARCHAR(32) USING md5(user_id::text);
ALTER TABLE bookmark_items ALTER COLUMN folder_id TYPE VARCHAR(32) USING CASE WHEN folder_id IS NULL THEN NULL ELSE md5(folder_id::text) END;
ALTER TABLE bookmark_tags ALTER COLUMN id TYPE VARCHAR(32) USING md5(id::text);
ALTER TABLE bookmark_tags ALTER COLUMN user_id TYPE VARCHAR(32) USING md5(user_id::text);
ALTER TABLE bookmark_item_tags ALTER COLUMN item_id TYPE VARCHAR(32) USING md5(item_id::text);
ALTER TABLE bookmark_item_tags ALTER COLUMN tag_id TYPE VARCHAR(32) USING md5(tag_id::text);

ALTER TABLE transfer_contents ADD CONSTRAINT transfer_contents_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE bookmark_folders ADD CONSTRAINT bookmark_folders_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE bookmark_folders ADD CONSTRAINT bookmark_folders_parent_owner_fk
  FOREIGN KEY (parent_id, user_id) REFERENCES bookmark_folders(id, user_id)
  ON DELETE RESTRICT DEFERRABLE INITIALLY IMMEDIATE;
ALTER TABLE bookmark_items ADD CONSTRAINT bookmark_items_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE bookmark_items ADD CONSTRAINT bookmark_items_folder_owner_fk
  FOREIGN KEY (folder_id, user_id) REFERENCES bookmark_folders(id, user_id)
  ON DELETE RESTRICT;
ALTER TABLE bookmark_tags ADD CONSTRAINT bookmark_tags_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
ALTER TABLE bookmark_item_tags ADD CONSTRAINT bookmark_item_tags_item_id_fkey
  FOREIGN KEY (item_id) REFERENCES bookmark_items(id) ON DELETE CASCADE;
ALTER TABLE bookmark_item_tags ADD CONSTRAINT bookmark_item_tags_tag_id_fkey
  FOREIGN KEY (tag_id) REFERENCES bookmark_tags(id) ON DELETE CASCADE;
ALTER TABLE bookmark_folders ADD CONSTRAINT bookmark_folders_parent_not_self
  CHECK (parent_id IS NULL OR parent_id <> id);
