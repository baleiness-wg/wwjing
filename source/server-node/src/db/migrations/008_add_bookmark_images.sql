ALTER TABLE bookmark_items
  ADD COLUMN IF NOT EXISTS images JSONB NOT NULL DEFAULT '[]'::jsonb;

UPDATE bookmark_items
SET images = jsonb_build_array(cover_url)
WHERE cover_url IS NOT NULL
  AND btrim(cover_url) <> ''
  AND images = '[]'::jsonb;

ALTER TABLE bookmark_items
  ADD CONSTRAINT bookmark_items_images_array_check
  CHECK (jsonb_typeof(images) = 'array');
