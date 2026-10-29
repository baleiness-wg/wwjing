# Proposal

## Why

当前 Android Flutter 客户端承担通用链接收藏，但“星标收藏”和“做饭收藏”需要不同的数据边界与整理方式。将现有客户端明确为 `flutter-star`，并新增使用同一账号但数据隔离的 `flutter-cookie`，可以复用成熟的登录、分享、标题识别和链接打开能力，同时为菜谱提供标签与“今天做什么”的轻量随机入口。

## What Changes

- 将现有 `source/flutter` Android Flutter 工程重命名为 `source/flutter_star`，更新 Dart 包名、Android 应用标识、应用名称、原生包路径和构建信息，保持原有收藏行为兼容。
- 抽取两个客户端共同使用的认证、安全存储、API 请求、分享文本解析、标题识别、外部 App 跳转、封面展示和基础收藏模型代码。
- 新增 `source/flutter_kitchen` Android Flutter 客户端，复用同一账号登录和链接接收流程，但只访问 `cookie` 数据空间。
- 为收藏夹条目和收藏夹增加 `space` 数据边界，使 `star` 与 `cookie` 数据按用户和应用空间隔离。
- 新增菜谱标签的创建、重命名、删除、选择和多标签分类能力；标签与收藏夹同时存在，一条菜谱可以拥有多个标签。
- 保持分享链接标题识别逻辑，优先使用分享文案和网页标题，再使用 URL 兜底；菜谱收藏允许用户编辑标题、描述、收藏夹和标签。
- 新增第一版简单随机功能，按当前 `cookie` 空间和可选分类条件随机返回一条菜谱，不实现“最近做过”排除规则。
- **BREAKING** 将原工程目录和 Android application ID 改为新名称；保留原账号和服务端数据，不改变 `flutter-star` 的业务语义。

## Capabilities

### New Capabilities

- `cookie-bookmark`: 覆盖做饭链接收藏、菜谱收藏夹、标签分类和简单随机菜谱。
- `bookmark-app-spaces`: 覆盖同一账号下 `star` 与 `cookie` 两个客户端的数据空间隔离。

### Modified Capabilities

- `bookmark-management`: 修改 Android 客户端工程身份和共享收藏接口，使原收藏客户端成为 `flutter-star`，并为收藏查询和写入增加空间参数。

## Impact

- 影响 `source/flutter` 的目录、Dart 导入、Android 原生包名、application ID、Intent 通道和构建配置。
- 新增 `source/flutter-cookie` Android Flutter 工程及菜谱页面、标签管理和随机入口。
- 新增共享 Flutter 代码边界，可能调整现有 `source/flutter-star` 的导入路径和测试结构。
- 修改 `source/server-node` 数据库迁移、收藏模型、服务、控制器和接口文档，新增空间字段、标签 API 和随机查询 API。
- 更新 `specs/bookmark-management` 主规格、构建信息和相关接口示例；不引入图片上传，封面仍沿用现有 URL 机制。
