CREATE TABLE IF NOT EXISTS folders (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, name)
);

INSERT INTO folders (user_id, name)
SELECT id, '默认收藏夹' FROM users
ON CONFLICT (user_id, name) DO NOTHING;

INSERT INTO folders (user_id, name)
SELECT users.id, folder_names.name
FROM users
CROSS JOIN (VALUES
  ('购物收藏夹'), ('文章收藏夹'), ('视频收藏夹'), ('代码收藏夹')
) AS folder_names(name)
ON CONFLICT (user_id, name) DO NOTHING;

ALTER TABLE favorite_details ADD COLUMN IF NOT EXISTS folder_id BIGINT REFERENCES folders(id) ON DELETE SET NULL;

UPDATE favorite_details AS i
SET folder_id = f.id
FROM folders AS f
WHERE f.user_id = i.user_id AND f.name = '默认收藏夹' AND i.folder_id IS NULL;

CREATE INDEX IF NOT EXISTS folders_user_id_idx ON folders(user_id);
CREATE INDEX IF NOT EXISTS favorite_details_folder_id_idx ON favorite_details(folder_id);
