# Design

## Context

当前前端使用 Vue 3、Vue Router 和 Element Plus，登录状态通过本地 token 保存；当前路由只有登录页和工具占位页，后端使用 Node.js、Express、JWT 和 PostgreSQL。现有 Node 服务已具备认证中间件、数据库连接池和 SQL 迁移器，但没有文件上传、下载或对应迁移。

本设计实现 proposal.md 和 `single-content-transfer` 规格中的最小闭环，不扩展为多任务传输系统。

## Goals / Non-Goals

**Goals:**

- 建立 `/`、`/tools`、`/tools/transfer` 的登录后页面结构。
- 让每个用户在数据库中拥有最多一条当前内容，内容类型为 `text` 或 `file`。
- 通过一个统一的二进制 payload 保存 UTF-8 文字或文件原始字节。
- 支持同账号跨设备读取文字、复制文字和下载文件。
- 使用数据库原子替换保证覆盖失败时旧内容不丢失。
- 在前后端共同执行 100 MB 文件大小限制。

**Non-Goals:**

- 不做传输码、分享链接或跨账号访问。
- 不做内容历史、多个文件、任务列表、断点续传或实时传输状态。
- 不做对象存储迁移、分块上传或大文件流式存储优化。
- 不新增未被需求声明的文字格式化、搜索或版本恢复能力。

## Decisions

### 统一内容表和 payload 字段

在 `source/server-node/src/db/migrations/` 新增 SQL 迁移创建 `transfer_contents` 表，使用 `user_id UNIQUE` 保证每个账号只有一条记录。记录包含 `content_type`、`payload BYTEA`、`file_name`、`mime_type`、`file_size`、创建时间和更新时间。文字先按 UTF-8 编码写入 payload，文件直接写入原始字节；读取时依据 content_type 解码或下载。

选择单个 `BYTEA` 字段而不是分别维护 `text_content` 与 `file_data`，因为产品语义是“一个账号一个当前内容”，两种内容互相覆盖，双字段会引入无效字段和状态一致性问题。文件元数据独立保存，因为下载响应需要文件名、媒体类型和大小。

### 通过认证上下文定位记录

内容 API 使用 Node 认证中间件提供的当前用户 ID 查询记录，不接受客户端传入的 `user_id`、账号名或可猜测内容 ID 作为授权依据。建议接口为：

```text
GET  /api/transfer/content
POST /api/transfer/content/text
POST /api/transfer/content/file
GET  /api/transfer/content/file
```

文字使用 JSON 请求；文件使用 multipart/form-data，由 Node 服务的 multipart 解析器处理。完整文件二进制不放入 JSON，避免 Base64 造成额外体积和内存开销。

### 覆盖使用单条原子写入

保存成功前完成内容读取、类型校验和大小校验，再通过 PostgreSQL 的按用户 upsert 替换记录。文件写入失败或请求被拒绝时不触碰旧记录；成功提交后旧内容随唯一记录被替换。

### 100 MB 限制在两层执行

前端在文件选择或拖拽后立即检查大小，避免无意义上传；后端设置请求体上限并在 multipart 解析后再次检查，后端校验是最终安全边界。超限返回 413 或项目统一的等价错误格式。

### 前端页面使用单页面内容类型切换

`/tools/transfer` 只使用一个页面，不拆分发送和接收路由。页面提供“文件”和“文字”输入入口，并根据查询到的 content_type 展示文件下载或文字复制。上传新内容后刷新当前内容状态，页面不维护历史列表。

## Risks / Trade-offs

- [Risk] PostgreSQL `BYTEA` 会让数据库直接承担文件存储，数据库备份和增长成本随文件大小增加。 -> [Mitigation] 初版严格限制单文件 100 MB，并保持单用户单条记录；后续规模扩大时再评估对象存储。
- [Risk] 一次性解析文件可能增加服务端内存和请求处理时间。 -> [Mitigation] 设置 Gin/HTTP 请求大小上限，先拒绝超限请求，并在实现验证中测试接近 100 MB 的文件。
- [Risk] upsert 替换可能让并发上传中的后一个请求覆盖前一个请求。 -> [Mitigation] 这是“当前内容直接覆盖”的明确产品语义；以最后一次成功提交为准，并保证失败请求不删除已有内容。
- [Risk] 旧项目数据库可能已经存在同名或不同版本迁移记录。 -> [Mitigation] 使用新的编号迁移并在部署前验证目标数据库 schema；迁移只新增表，不修改已有业务表。

## Migration Plan

1. 在 Node 服务的 SQL 迁移目录增加迁移，创建 `transfer_contents` 表、用户外键和 `user_id` 唯一约束。
2. 部署后端接口和前端页面，验证登录、空状态、文字覆盖、文件覆盖、不同账号隔离和下载。
3. 若发布需要回滚，先回滚前端入口和后端路由，再保留新增表以避免误删用户数据；确认不再需要后通过独立数据库运维变更清理。

## Open Questions

无。文字和文件共用 payload、每账号一条、直接覆盖、同账号访问及 100 MB 文件上限均已确定。
