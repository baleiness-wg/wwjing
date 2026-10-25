# Proposal

## Why

用户在手机应用中刷到视频或网页链接后，缺少一个低摩擦、可跨设备整理的私人收藏入口。现有系统已经具备统一账号、Node API、PostgreSQL 和 Web 管理端，适合增加一个以 Android 分享入口为主、Web 后台整理为辅的收藏夹能力。

## What Changes

- 在 `source/flutter/` 增加第一版仅支持 Android 的 Flutter 客户端，复用现有用户名密码登录和 Bearer JWT。
- Android 客户端接收系统分享的文本或链接，并在打开应用时对剪贴板中的 HTTP/HTTPS 链接进行粗略识别；用户可编辑标题、描述并选择收藏夹后保存。
- 提供可嵌套的私人收藏夹目录，每个目录可新增子目录或链接收藏，并支持重命名、移动、排序和删除。
- 提供链接收藏的创建、查看、编辑、移动、搜索和删除能力；保存原始链接、规范化链接、来源域名及可扩展元数据。
- 在 `server-node` 增加按用户隔离的收藏夹与收藏条目 API，并扩展 PostgreSQL 数据模型和迁移。
- 在 Vue Web 的“工具”菜单下增加“收藏夹”管理页面，用于目录整理、搜索及批量管理，与 Android 客户端共享数据。
- 第一版不解析视频详情、不下载内容、不支持 iOS、不提供标签、多目录归属或多人共享收藏夹。

## Capabilities

### New Capabilities

- `bookmark-management`: 覆盖用户私有嵌套收藏夹、链接收藏、Android 快速接收与分类、Web 后台整理及跨端一致性。

### Modified Capabilities

无。

## Impact

- 新增 `source/flutter/` Android Flutter 工程及 Android 系统分享接入。
- 修改 `source/server-node` 的数据库迁移、模型、控制器、路由和测试，新增 `/api/bookmarks` 接口族。
- 修改 `source/web` 的路由、工具导航、API 客户端和收藏夹管理视图。
- 复用现有 `users` 表、JWT 签发方式和认证中间件；Flutter 端需安全保存 JWT。
- PostgreSQL 新增收藏夹和收藏条目表、用户隔离索引及目录关系约束。
