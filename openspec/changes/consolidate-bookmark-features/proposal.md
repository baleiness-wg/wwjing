# Proposal

## Why

当前收藏系统经过多次功能重构和 UI 调整，Flutter、Node API、Web、数据库迁移及 Android 分享链路的实际行为已经分散在多个版本中。需要将现有功能重新收敛为一份可验证的系统契约，避免后续 UI 修改误伤平台跳转、剪贴板识别、封面识别和异步保存。

## What Changes

- 统一记录 Android Flutter 客户端、Node 服务、Web 管理端和 PostgreSQL 收藏模型的当前行为。
- 保留 kitchen/star 双模式、登录、系统分享、剪贴板识别、编辑中切换确认和平台 App 定向跳转。
- 明确收藏条目标题必填，描述和 URL 可选；非空 URL 继续规范化和重复判断。
- 明确图片使用 `images` 有序数组，旧 `cover_url` 数据迁移到数组首项；识别结果异步保存并刷新列表。
- 保留小红书短链解析、真实封面提取、Logo 过滤和 `xhsdiscover` 内容跳转。
- 明确主页通过左侧目录切换，目录视图展示当前目录及后代目录中的视频，不再在主页混排子目录卡片。
- 明确目录树、目录选择器的折叠、操作高亮和紧凑布局行为，以及收藏列表批量全选操作。
- 补齐数据库迁移、接口文档、测试和部署验证要求。

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `bookmark-app-modes`: 修改统一收藏客户端的分享、剪贴板、平台跳转、收藏编辑、图片数组和目录内容展示要求。
- `navigation-layout`: 修改 Flutter 目录树/选择器折叠与高亮、主页列表密度和批量编辑交互要求。

## Impact

- Flutter：`source/flutter_bookmark/lib/` 的状态、表单、主页、目录导航、目录选择器、图片模型和平台跳转。
- Node：收藏服务、模型、元数据解析、图片数组迁移和图片上传预留接口。
- Web：收藏列表、编辑表单、图片数组展示和多空间入口。
- Database：`bookmark_items.images`、可空 URL 字段及历史封面数据迁移。
- Tests：Flutter widget/unit tests、Node service/API tests、Web API tests。
- Deployment：生产数据库迁移、Docker 重建和共享 PostgreSQL 网络验证。
