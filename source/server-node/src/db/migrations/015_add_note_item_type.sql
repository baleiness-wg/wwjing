ALTER TABLE bookmark_items
  DROP CONSTRAINT IF EXISTS bookmark_items_item_type_check;

ALTER TABLE bookmark_items
  ADD CONSTRAINT bookmark_items_item_type_check
  CHECK (item_type IN ('link', 'inspiration', 'note'));

UPDATE bookmark_items
SET item_type = 'note'
WHERE item_type = 'link' AND source_url IS NULL;
