ALTER TABLE bookmark_items
  DROP CONSTRAINT IF EXISTS bookmark_items_item_type_check;

ALTER TABLE bookmark_items
  ADD CONSTRAINT bookmark_items_item_type_check
  CHECK (item_type IN ('link', 'inspiration'));

ALTER TABLE bookmark_items
  ADD CONSTRAINT bookmark_items_inspiration_content_check
  CHECK (item_type = 'link' OR char_length(btrim(coalesce(description, ''))) > 0);

INSERT INTO bookmark_items (
  id, user_id, space, folder_id, item_type, title, description,
  images, source_url, normalized_url, source_host, metadata, created_at, updated_at
)
SELECT
  entry.id, entry.user_id, entry.space, entry.folder_id, 'inspiration',
  entry.title, entry.content, '[]'::jsonb, NULL, NULL, NULL,
  '{}'::jsonb, entry.created_at, entry.updated_at
FROM inspiration_entries entry
ON CONFLICT (id) DO NOTHING;

DROP TABLE IF EXISTS inspiration_entries;
