ALTER TABLE bookmark_items
  DROP CONSTRAINT IF EXISTS bookmark_items_item_type_check;

ALTER TABLE bookmark_items
  DROP CONSTRAINT IF EXISTS bookmark_items_inspiration_content_check;

ALTER TABLE bookmark_items
  ADD CONSTRAINT bookmark_items_item_type_check
  CHECK (item_type IN ('link', 'inspiration', 'note'));

ALTER TABLE bookmark_items
  ADD CONSTRAINT bookmark_items_inspiration_content_check
  CHECK (
    item_type = 'link'
    OR char_length(btrim(coalesce(description, ''))) > 0
    OR char_length(btrim(coalesce(title, ''))) > 0
  );

UPDATE bookmark_items
SET item_type = 'note'
WHERE item_type = 'link' AND source_url IS NULL;
