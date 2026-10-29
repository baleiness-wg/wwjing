CREATE TABLE IF NOT EXISTS bookmark_tags (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  space VARCHAR(20) NOT NULL CHECK (space IN ('star', 'cookie')),
  name VARCHAR(80) NOT NULL CHECK (char_length(btrim(name)) > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT bookmark_tags_user_space_name_unique UNIQUE (user_id, space, name),
  CONSTRAINT bookmark_tags_id_user_space_unique UNIQUE (id, user_id, space)
);

CREATE TABLE IF NOT EXISTS bookmark_item_tags (
  item_id BIGINT NOT NULL REFERENCES bookmark_items(id) ON DELETE CASCADE,
  tag_id BIGINT NOT NULL REFERENCES bookmark_tags(id) ON DELETE CASCADE,
  PRIMARY KEY (item_id, tag_id)
);

CREATE INDEX IF NOT EXISTS bookmark_tags_user_space_idx ON bookmark_tags(user_id, space, name);
CREATE INDEX IF NOT EXISTS bookmark_item_tags_tag_idx ON bookmark_item_tags(tag_id, item_id);
