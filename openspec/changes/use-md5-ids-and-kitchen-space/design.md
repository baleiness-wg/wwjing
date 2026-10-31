# Design

## Context

现有数据库以 `BIGSERIAL` 作为用户、收藏条目和目录等主键；用户 ID 通过 JWT `sub` 传递，收藏条目 ID 出现在 REST 路径中。服务端已对收藏空间做 `star` / `cookie` 校验，Flutter 与 Web 也硬编码 `cookie`。迁移器按文件顺序逐条执行 SQL，每条迁移在单独事务中提交，失败会回滚。

参见 `proposal.md` 了解动机，参见 `specs/entity-identifiers/spec.md` 与 `specs/bookmark-app-modes/spec.md` 了解行为要求。

## Goals / Non-Goals

**Goals:**

- 用户与收藏条目使用稳定、可推导、可校验的 32 位小写 MD5 字符串主键。
- 既有用户、目录、收藏、标签、传输内容在迁移后保持归属关系与数量。
- kitchen 空间在数据库、API、Flutter、Web 中统一为 `kitchen`。
- 迁移失败时不留下部分转换的数据。

**Non-Goals:**

- 不将目录、标签、传输内容自身主键改为 MD5。
- 不保留 `cookie` 兼容别名，不做双写或渐进式空间切换。
- 不为迁移提供自动回滚脚本；回滚依赖部署前备份。

## Decisions

### 用户 ID 使用 `MD5(username)`

注册时由 Node `crypto` 生成小写十六进制 MD5；迁移时使用 PostgreSQL 内置 `md5()` 对既有 `username` 计算。选择确定性哈希而非随机 UUID，满足“ID 可由业务数据推导”的诉求，并避免迁移时需要外部映射表。

替代方案：随机 UUID 再取 MD5。拒绝原因是同一用户名在不同环境无法得到同一 ID，排障和跨环境比对困难。

### 收藏条目 ID 使用作用域化 `MD5(userId:space:normalizedUrl)`

哈希输入包含用户、空间和既有规范化 URL，保证全局主键唯一，同时允许不同用户或不同空间收藏同一链接。选择作用域化哈希而非纯 `MD5(normalizedUrl)`，否则不同用户收藏同一链接会发生主键冲突，或被迫改成复合主键并连带重构 `bookmark_item_tags` 外键。

替代方案：`id = MD5(normalizedUrl)`，主键改为 `(user_id, space, id)`。拒绝原因是收藏条目接口、标签关联和客户端都以单列 `id` 定位，复合主键会扩大改动面且不符合当前 API 形态。

### 主键与关联列使用 `CHAR(32)`

数据库使用 `CHAR(32)` 存储小写十六进制，避免可变长度索引碎片；Node 与客户端统一按字符串处理。`users.id`、所有 `user_id`、`bookmark_items.id`、`bookmark_item_tags.item_id` 同步改类型；目录、标签、传输内容自身 `id` 保持 `BIGSERIAL`。

### 单次事务迁移，先校验后改写

新增迁移 `007_use_md5_ids_and_kitchen_space.sql`，在迁移器事务内执行：

1. 预检同一 `(user_id, space, normalized_url)` 是否存在重复收藏；存在则 `RAISE EXCEPTION`，事务回滚。
2. 为 `users`、`bookmark_items` 及各关联表增加临时新标识列并填充。
3. 删除引用旧主键的外键、唯一约束和主键约束。
4. 用临时列替换旧列并重建主键、唯一约束、外键和索引。
5. 删除旧空间约束，将 `cookie` 更新为 `kitchen`，再创建只允许 `star` / `kitchen` 的约束。
6. 校验关联表无悬空引用后提交。

替代方案：在应用启动时逐行转换。拒绝原因是迁移器已提供事务边界，SQL 迁移更快且失败可回滚。

### `cookie` 不保留别名

服务端只接受 `star` 与 `kitchen`；旧客户端发送 `cookie` 会得到 `INVALID_SPACE`。选择同步切换而非兼容别名，避免数据库、API 与客户端长期存在两套名称。代价是服务端、Flutter、Web 必须同批发布。

### 旧 JWT 自然失效

既有 token 的 `sub` 是数字字符串，迁移后无法匹配新用户 ID。选择接受旧 token 失效并要求重新登录，不编写 token 迁移逻辑；JWT 本身无状态，强制重新登录成本低于维护双格式解析。

## Risks / Trade-offs

- [既有数据存在重复规范化 URL，迁移中止] → 迁移先执行分组计数预检并输出冲突的用户、空间和 URL；由运维清理后再重试，绝不自动合并或删除。
- [类型变更期间外键/约束遗漏导致关联断裂] → 迁移在单事务内完成，并在提交前检查各关联表悬空行数必须为 0。
- [服务端先于客户端发布，旧客户端收到 `INVALID_SPACE`] → 同批发布服务端、Flutter、Web；发布窗口内提示用户更新客户端。
- [旧 JWT 全部失效] → 发布说明明确要求重新登录；客户端既有 401 清除令牌逻辑会引导登录。
- [MD5 碰撞或人为构造冲突] → 用户 ID 依赖用户名唯一约束，收藏 ID 依赖作用域化输入与重复校验；迁移和写入冲突均返回明确错误，不静默覆盖。
- [大表转换锁表时间较长] → 在低峰期执行；先备份数据库，必要时从备份恢复。

## Migration Plan

1. 备份 `wwjing_db`，确认可恢复。
2. 发布新服务端代码与 `007` 迁移；迁移失败则服务端启动失败，数据库保持不变。
3. 验证用户、目录、收藏、标签、传输内容数量与抽样关联关系。
4. 发布 Flutter 与 Web 版本，统一切换到 `kitchen` 空间值。
5. 回滚策略：恢复发布前数据库备份并回退服务端与客户端版本；不提供反向 SQL 迁移。

## Open Questions

无。
