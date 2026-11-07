ALTER TABLE bookmark_items
  ALTER COLUMN source_url DROP NOT NULL,
  ALTER COLUMN normalized_url DROP NOT NULL,
  ALTER COLUMN source_host DROP NOT NULL;
