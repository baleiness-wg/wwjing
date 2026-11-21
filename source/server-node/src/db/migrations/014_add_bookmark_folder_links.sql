CREATE TABLE IF NOT EXISTS bookmark_item_folders (
  item_id VARCHAR(32) NOT NULL REFERENCES bookmark_items(id) ON DELETE CASCADE,
  folder_id VARCHAR(32) NOT NULL REFERENCES bookmark_folders(id) ON DELETE CASCADE,
  PRIMARY KEY (item_id, folder_id)
);

INSERT INTO bookmark_item_folders (item_id, folder_id)
SELECT id, folder_id FROM bookmark_items WHERE folder_id IS NOT NULL
ON CONFLICT DO NOTHING;

CREATE INDEX IF NOT EXISTS bookmark_item_folders_folder_idx
  ON bookmark_item_folders(folder_id, item_id);
