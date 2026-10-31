# Proposal

## Why

当前用户与收藏条目使用数据库自增整数作为主键，标识无法由业务数据推导，跨环境迁移和排障时难以对应；同时 kitchen 模式在数据库和 API 中使用 `cookie` 作为空间值，与模式名称不一致，容易造成误解。本次变更将用户与收藏条目的主键改为 MD5 字符串，并把 kitchen 空间值统一为 `kitchen`。

## What Changes

- **BREAKING**：`users.id` 由 `BIGSERIAL` 改为 32 位小写十六进制 MD5 字符串，取值为 `MD5(username)`。
- **BREAKING**：`bookmark_items.id` 由 `BIGSERIAL` 改为 32 位小写十六进制 MD5 字符串，取值为 `MD5(userId + ":" + space + ":" + normalizedUrl)`，避免不同用户或空间收藏同一链接时主键冲突。
- 所有引用用户主键的列（收藏目录、收藏条目、标签、传输内容）同步改为 32 位字符串外键；`bookmark_item_tags.item_id` 同步改为 32 位字符串外键。
- 保持 `bookmark_folders`、`bookmark_tags`、`transfer_contents` 自身主键为现有自增整数，仅调整其 `user_id` 外键类型。
- **BREAKING**：kitchen 模式的收藏空间值由 `cookie` 统一改为 `kitchen`，覆盖数据库约束、既有数据、服务端校验、Flutter 客户端和 Web 客户端。
- 新增数据库迁移：迁移既有用户与收藏条目的整数主键到 MD5，并同步更新所有关联表；若同一用户同一空间存在规范化 URL 重复的条目，迁移在写入前明确失败，避免静默丢数据。
- 更新接口文档与项目规格中的 ID 格式、空间值和示例数据。

## Capabilities

### New Capabilities

- `entity-identifiers`: 定义用户与收藏条目的稳定 MD5 标识生成规则、格式校验、唯一性边界及关联列类型。

### Modified Capabilities

- `bookmark-app-modes`: kitchen 模式的收藏空间值由 `cookie` 改为 `kitchen`，包括 API 参数、数据库约束与 Web/移动端行为。

## Impact

- **数据库**：`users`、`bookmark_folders`、`bookmark_items`、`bookmark_tags`、`bookmark_item_tags`、`transfer_contents` 的主键/外键类型与既有数据。
- **服务端**：用户注册、登录 JWT `sub`、收藏条目创建/查询/更新/删除、随机推荐、标签、迁移脚本及错误码。
- **Flutter**：`AppConfig.kitchen.space` 改为 `kitchen`，所有请求与测试夹具同步。
- **Web**：路由 meta、API 默认参数、`BookmarksView` 空间判断与测试同步。
- **文档**：根目录 `specs/bookmark-app-modes/spec.md`、`specs/bookmark-management/spec.md`、`source/server-node/README.http`。
- **兼容性**：ID 从数字变为字符串、空间值从 `cookie` 变为 `kitchen` 均为破坏性变更，服务端与移动端/Web 需同步部署；本次不保留 `cookie` 别名。
