-- category on items is the content type. Folders are user-named collections.
INSERT INTO folders (user_id, name)
SELECT id, '默认收藏夹' FROM users
ON CONFLICT (user_id, name) DO NOTHING;

UPDATE items AS i
SET folder_id = f.id
FROM folders AS f
WHERE f.user_id = i.user_id
  AND f.name = '默认收藏夹'
  AND (
    i.folder_id IS NULL
    OR EXISTS (
      SELECT 1 FROM folders AS old_f
      WHERE old_f.id = i.folder_id
        AND old_f.name IN ('购物收藏夹', '文章收藏夹', '视频收藏夹', '代码收藏夹')
    )
  );

DELETE FROM folders
WHERE name IN ('购物收藏夹', '文章收藏夹', '视频收藏夹', '代码收藏夹');
