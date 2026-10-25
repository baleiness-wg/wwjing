# Design

## Context

现有系统由 `source/server-node` 的 Express API、PostgreSQL 数据库和 `source/web` 的 Vue 3 管理端组成。认证使用用户名密码登录和有效期 7 天的 HS256 Bearer JWT，API 通过 JWT `sub` 确定当前用户。数据库迁移按 SQL 文件名排序执行，Web 已有“工具”二级导航和统一请求封装。

本变更横跨新的 Android Flutter 客户端、现有 Node 服务、数据库和 Web 管理端。收藏操作的首要约束是从外部应用分享链接后尽快完成分类保存；目录整理、搜索和批量操作则主要由 Web 承担。参见 `proposal.md` 和 `specs/bookmark-management/spec.md`。

## Goals / Non-Goals

**Goals:**

- Android 通过系统分享和用户主动打开后的剪贴板提示接收链接。
- Flutter 与 Web 复用同一认证和收藏 API，并在刷新后保持数据一致。
- 使用简单、可验证的数据模型支持用户私有嵌套目录和可扩展链接条目。
- 保持快速保存路径可在单个表单内完成，并妥善恢复登录过期时的待收藏内容。
- 通过数据库约束、事务和服务端所有权校验保护目录结构及用户隔离。

**Non-Goals:**

- 不实现 iOS、浏览器扩展或桌面 Flutter 平台。
- 不抓取目标网页、不展开短链接、不解析视频封面、作者和时长。
- 不下载或离线缓存收藏内容。
- 不实现标签、多收藏夹归属、协作共享或公开链接。
- 不在本变更中重构现有 JWT 为 refresh token 体系。

## Decisions

### 1. Flutter 工程采用 Android-only 平台范围

在 `source/flutter/` 建立 Flutter 应用，仅生成和维护 Android 平台文件。通过 Android `ACTION_SEND` 的 `text/plain` Intent 接收分享文本，并在 Flutter 生命周期恢复时处理冷启动和已运行两种分享场景。

选择 Android-only 是因为当前主要场景为手机视频应用分享，且 iOS Share Extension 的生命周期、签名和数据共享方式会显著扩大第一版范围。替代方案是同时生成 iOS 工程，但会产生未验证且无法满足验收的代码，因此不采用。

### 2. 系统分享为主入口，剪贴板为显式辅助入口

系统分享文本进入统一的链接提取器，提取第一个 HTTP/HTTPS URL，并保留完整原文作为描述草稿。剪贴板仅在用户主动打开或恢复应用时读取；检测到新链接后显示提示，不自动保存，并记录本次已忽略或已处理链接的摘要以避免重复提示。

替代方案是在后台持续监视剪贴板，但现代 Android 对剪贴板访问有隐私提示和后台限制，也会造成不必要的信任问题，因此不采用。

### 3. 复用 JWT API，Flutter 使用安全存储

Flutter 直接调用现有 `/api/auth/login` 并复用 `Bearer <token>` 格式。令牌保存到 Android Keystore 支撑的安全存储；API 层统一附加认证头并在 401 时清除失效凭证。收到分享后若需要登录，应用在内存和受控临时状态中保留待收藏草稿，登录成功后返回表单。

第一版不增加 refresh token。代价是用户每 7 天可能重新登录，但避免同时扩大认证协议、数据库和 Web 登录行为。待实际使用证明中断明显后，再单独设计刷新令牌。

### 4. 收藏夹使用带用户隔离的邻接表

新增 `bookmark_folders`：

```text
id            BIGSERIAL PRIMARY KEY
user_id       BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE
parent_id     BIGINT NULL REFERENCES bookmark_folders(id) ON DELETE RESTRICT
name          VARCHAR(120) NOT NULL
position      INTEGER NOT NULL DEFAULT 0
created_at    TIMESTAMPTZ NOT NULL
updated_at    TIMESTAMPTZ NOT NULL
```

邻接表符合读取完整树、创建子目录和移动目录的主要操作，模型简单且适用于当前规模。服务层在事务中验证父目录所有权，并使用递归 CTE 检查目标父目录是否为当前目录的后代。目录删除采用“非空拒绝”，避免级联误删。

替代方案包括 materialized path 和 closure table。前者移动目录需更新整棵子树，后者写入与维护成本更高；当前不需要极深树或复杂祖先查询，因此不采用。应用层限制最大深度为 8 层，防止误操作形成不可用结构。

同一父目录下名称允许重复，避免引入大小写、语言和重命名冲突规则；客户端以标识而非路径识别目录。

### 5. 收藏条目使用单目录归属和 JSONB 扩展元数据

新增 `bookmark_items`：

```text
id              BIGSERIAL PRIMARY KEY
user_id         BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE
folder_id       BIGINT NULL REFERENCES bookmark_folders(id) ON DELETE RESTRICT
item_type       VARCHAR(20) NOT NULL DEFAULT 'link'
title           TEXT NULL
description     TEXT NULL
source_url      TEXT NOT NULL
normalized_url  TEXT NOT NULL
source_host     TEXT NOT NULL
metadata        JSONB NOT NULL DEFAULT '{}'
created_at      TIMESTAMPTZ NOT NULL
updated_at      TIMESTAMPTZ NOT NULL
```

第一版 `item_type` 只允许 `link`，但字段和 `metadata` 为以后增加封面、作者或其他内容类型保留迁移空间。`folder_id IS NULL` 表示未分类，不创建特殊目录记录。一条收藏只属于一个目录，从而保持移动、删除和列表行为清晰。

替代方案是立即建立条目与目录多对多关系，但会使“移动”和“复制”语义、重复展示及删除确认复杂化，不符合快速收藏 MVP。

### 6. URL 规范化保守执行，重复不设数据库唯一约束

服务端解析 URL，仅接受 `http:` 和 `https:`；协议和主机转为小写，移除 fragment、默认端口、已知追踪参数及非根路径末尾斜杠，保留其他路径和查询参数。保存 `source_host` 供来源展示和筛选。

创建前按 `user_id + normalized_url` 查询重复项。首次请求发现重复时返回冲突响应和已有条目摘要；客户端显式设置 `allowDuplicate` 后才能继续创建。数据库不添加唯一约束，因为用户可能用不同标题和描述保存同一链接的不同上下文。

不请求目标 URL，也不跟随短链接，以避免 SSRF、平台反爬和延迟问题。

### 7. REST API 按 folders 与 items 分区

新增认证路由：

```text
GET    /api/bookmarks/folders
POST   /api/bookmarks/folders
PATCH  /api/bookmarks/folders/:id
DELETE /api/bookmarks/folders/:id

GET    /api/bookmarks/items
POST   /api/bookmarks/items
GET    /api/bookmarks/items/:id
PATCH  /api/bookmarks/items/:id
DELETE /api/bookmarks/items/:id
```

目录 GET 返回扁平数组，由客户端组树。条目列表支持 `folderId`、`uncategorized`、`query`、`page`、`pageSize` 参数，默认按 `updated_at DESC, id DESC` 稳定分页。创建和移动时，服务端必须校验 `folder_id` 属于当前用户。

目录重排通过 PATCH 提交 `parentId` 和 `position`；第一版不要求拖拽操作原子重排所有兄弟目录，服务端按 position、name、id 稳定展示。

### 8. Flutter 使用响应式主从布局

应用核心页面由目录导航、条目列表和编辑/快速收藏表单组成。窄屏使用抽屉展示目录，宽屏使用常驻左栏。目录选择器将最近使用目录置顶，并同时提供可展开树；最近目录标识保存在本地，不改变服务端模型。

网络保存完成前表单保持可见并显示进度；失败时保留用户输入。第一版不做离线写队列，避免重复创建和冲突合并，但网络不可用时必须明确提示且不丢失当前表单。

### 9. Web 将收藏夹作为工具子页面

在现有 `/tools` 下新增 `/tools/bookmarks`，并在 `AppLayout` 与 `ToolsView` 增加入口。页面内部独立维护目录树，不将用户目录注入全局应用导航。桌面布局采用左侧目录树、右侧搜索和条目管理区域；移动 Web 保持基本可用，但主要后台管理目标为桌面和 Pad。

批量管理限定为多选后移动或删除条目；批量 API 可在客户端并发调用单条接口，第一版不额外设计批量服务端端点。

## Risks / Trade-offs

- [7 天 JWT 在分享时过期会中断操作] -> Flutter 暂存分享草稿并在重新登录后恢复，后续根据使用反馈独立设计 refresh token。
- [邻接表循环检查存在并发竞争] -> 在同一数据库事务中锁定被移动目录并执行递归后代检查；限制目录深度为 8。
- [同名目录导致路径显示歧义] -> UI 显示完整面包屑并始终使用目录 ID 操作；第一版允许同级同名以减少命名规则复杂度。
- [URL 规范化误判不同内容为重复] -> 重复仅提示、不强制禁止；保留原始 URL，允许明确继续保存。
- [Android 厂商对分享 Intent 行为存在差异] -> 覆盖冷启动、热启动、纯链接和混合文本测试，并允许用户在 App 内手动粘贴链接。
- [剪贴板读取触发系统隐私提示] -> 只在应用前台且用户主动打开时读取，不做后台监听，不自动上传或保存。
- [目录或条目数量增长影响全量目录读取] -> 目录树保持全量扁平读取并建立 `user_id, parent_id, position` 索引；条目列表必须分页和索引查询。
- [JSONB 元数据成为无约束杂项] -> 第一版 API 只写空对象，不开放客户端任意 metadata 写入；未来解析功能按版本定义字段。

## Migration Plan

1. 增加数据库迁移，创建收藏夹与收藏条目表、外键、检查约束和索引；迁移只新增对象，不改变现有表结构。
2. 部署 `server-node` 收藏 API 和测试，执行迁移后进行用户隔离、循环目录和重复链接冒烟验证。
3. 部署 Web 收藏夹入口；服务端不可用时不影响现有数据传输工具。
4. 构建并安装 Android Flutter 测试包，验证登录、分享冷/热启动、剪贴板提示和跨端同步。
5. 回滚应用时可先撤回 Flutter/Web 入口和 API 路由；新增表保留以避免数据丢失。确认无需保留数据后再通过单独迁移删除，不在应用回滚中自动删表。
