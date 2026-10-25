ALTER TABLE bookmark_items
  ADD COLUMN IF NOT EXISTS cover_url TEXT;
