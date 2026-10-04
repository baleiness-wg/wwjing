DROP TABLE IF EXISTS items CASCADE;
TRUNCATE favorite_details RESTART IDENTITY CASCADE;

CREATE TABLE IF NOT EXISTS folders (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, name)
);

INSERT INTO folders (user_id, name)
SELECT users.id, folder_names.name
FROM users
CROSS JOIN (VALUES
  ('默认收藏夹'), ('购物收藏夹'), ('文章收藏夹'), ('视频收藏夹'), ('代码收藏夹')
) AS folder_names(name)
ON CONFLICT (user_id, name) DO NOTHING;

ALTER TABLE favorite_details
  ADD COLUMN IF NOT EXISTS category VARCHAR(30) NOT NULL DEFAULT 'text',
  ADD COLUMN IF NOT EXISTS folder_id BIGINT REFERENCES folders(id) ON DELETE SET NULL;

UPDATE favorite_details AS detail
SET folder_id = folder.id
FROM folders AS folder
WHERE folder.user_id = detail.user_id
  AND folder.name = '默认收藏夹'
  AND detail.folder_id IS NULL;

CREATE INDEX IF NOT EXISTS favorite_details_folder_id_idx
  ON favorite_details(folder_id);
