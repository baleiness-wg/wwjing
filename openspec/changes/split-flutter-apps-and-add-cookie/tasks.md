# Tasks

## 1. 服务端空间隔离

- [x] 1.1 新增收藏夹和收藏条目的 `space` 字段、允许值约束、默认值和索引迁移，将既有数据标记为 `star`；运行数据库迁移并核对结构和旧数据。
- [x] 1.2 更新收藏夹、收藏条目模型和服务层，使所有列表、创建、修改、移动、删除、重复检测和递归查询同时校验用户与空间；新增跨空间访问测试并运行 Node 测试。
- [x] 1.3 更新收藏 API 接口的空间参数校验和调试文档，确保 Web 继续固定使用 `star`；运行认证、用户隔离和空间隔离 API 测试。

## 2. 标签与随机菜谱 API

- [x] 2.1 新增 `bookmark_tags`、`bookmark_item_tags` 表及模型，支持同一用户同一空间内标签唯一、多标签关联和删除标签不删除条目；通过模型测试验证重复标签和用户隔离。
- [x] 2.2 新增标签查询、创建、重命名、删除和收藏条目标签更新 API，校验标签与条目属于同一用户和 `cookie` 空间；运行 CRUD、空标签和非法空间测试。
- [x] 2.3 新增认证随机菜谱接口，支持 `cookie` 空间、可选收藏夹和标签过滤，返回单条随机菜谱或明确空状态；通过服务和路由测试验证不读取 `star` 数据。
- [x] 2.4 更新主规格、接口说明、`README.http` 和受影响模块 `build.json`，核对空间、标签和随机接口示例可执行。

## 3. 共享 Flutter 基础与 flutter_star 迁移

- [x] 3.1 将现有 `source/flutter` 迁移为 `source/flutter_star`，更新 pubspec 名称、Android namespace/application ID、Kotlin 包路径、MethodChannel、应用名称、分享 Intent 和构建信息；验证目录和包名引用无旧标识残留。
- [x] 3.2 抽取认证、安全存储、API 客户端、分享服务、标题解析、外部 App 跳转、通用模型和目录/封面组件到 `source/flutter_shared`，让 `flutter_star` 通过共享依赖编译；运行 `flutter pub get` 和 `flutter analyze`。
- [x] 3.3 为共享 API 客户端增加固定 `space` 参数，让 `flutter-star` 全部收藏请求使用 `star`；运行现有 Flutter 测试并验证原有分享、标题、目录和打开 App 行为。
- [x] 3.4 为 `flutter-star` 更新测试导入、README、Android debug 构建和 `build.json`，确认原有账号登录后只能读取 `star` 空间。

## 4. flutter-cookie 应用

- [x] 4.1 基于共享 Flutter 基础创建仅 Android 的 `source/flutter_kitchen` 工程，设置 `wwjing_kitchen`、独立 application ID 和中文应用名称；运行 `flutter pub get`、`flutter analyze` 和基础测试。
- [x] 4.2 实现 cookie 空间登录、系统分享/剪贴板接收、标题和描述预填、收藏夹选择、封面 URL 编辑和链接打开，复用共享解析逻辑；通过 widget 测试验证分享文案优先于 URL 标题。
- [x] 4.3 实现做饭收藏夹浏览、创建、重命名、移动、删除、搜索和收藏条目编辑/删除，所有请求固定使用 `cookie`；通过 widget/API 集成测试验证与 `star` 数据隔离。
- [x] 4.4 实现标签管理界面和收藏表单多标签选择，支持创建、重命名、删除、筛选和移除标签；通过 widget 测试验证一条菜谱可关联多个标签。
- [x] 4.5 实现“今天做什么”简单随机入口，支持全部菜谱、当前收藏夹和标签筛选，空结果显示明确提示；通过状态和 widget 测试验证随机结果属于当前 `cookie` 空间。
- [x] 4.6 实现 cookie 工程的 Android 分享 Intent、返回导航、构建配置和 `build.json`，运行 debug APK 构建并验证可独立安装。

## 5. 双应用集成验证

- [x] 5.1 使用同一测试账号验证 `flutter-star` 与 `flutter-cookie` 登录成功但目录、条目、标签和搜索结果完全隔离。
- [x] 5.2 完成跨端/跨应用流程：星标分享保存到 `star`，菜谱分享保存到 `cookie`，标签筛选和随机菜谱只返回 cookie 数据；记录实际验证结果。
- [x] 5.3 运行 Node 全量测试、Web 构建、共享 Flutter/`flutter-star`/`flutter-cookie` 的 analyze 与 test，以及两个 Android debug 构建；修复所有失败并核对 `git diff --check`。

## Workflow follow-up

- 归档变更前同步新能力规格到主规格，并确认旧 `source/flutter` 路径已完成迁移。
- 实现验收完成后运行 `/opsx-archive`。
