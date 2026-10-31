# Proposal

## Why

`flutter_kitchen` 与 `flutter_star` 当前维护两套高度重复的 Flutter 代码，仅应用名称、Android 标识和收藏空间等模式差异需要区分，重复维护容易造成修复和功能漂移。将它们收敛为 `flutter_bookmark` 单工程并通过编译期 `APP_TYPE` 选择模式，可以共享收藏、分享和平台跳转实现，同时让 kitchen 模式提供“今天吃什么”的低摩擦随机入口。

## What Changes

- **BREAKING**：以 `source/flutter_bookmark/` 作为唯一 Flutter 工程，替代独立的 `source/flutter_kitchen/` 与 `source/flutter_star/` 工程。
- 通过 `--dart-define=APP_TYPE=kitchen` 或 `--dart-define=APP_TYPE=star` 在编译期选择应用模式，并由模式统一决定应用名称、收藏空间、Android 应用标识及 MethodChannel 名称等配置。
- 保持两种模式现有的登录、系统分享、剪贴板、目录、收藏和搜索能力，避免合并导致功能回退。
- kitchen 模式增加随机按钮；点击后请求当前用户 `cookie` 空间的随机收藏，并在低高度弹窗中显示一个与列表一致的链接卡片。
- 随机结果卡片不显示 checkbox 和编辑、移动、删除等操作按钮；点击卡片使用统一平台跳转服务打开对应 App。
- 统一 Bilibili、小红书和抖音的 Android 跳转策略；小红书短链在保存前解析并持久化完整最终 URL，保留内容标识和分享查询参数。
- star 模式不显示随机按钮，也不请求随机菜谱接口。

## Capabilities

### New Capabilities

- `bookmark-app-modes`: 覆盖统一 Flutter 收藏客户端的编译期模式选择、模式隔离配置、kitchen 随机推荐弹窗及模式一致的平台链接跳转行为。

### Modified Capabilities

无。

## Impact

- Flutter 工程：`source/flutter_kitchen/`、`source/flutter_star/` 收敛至 `source/flutter_bookmark/`，共享 Dart、测试和 Android 原生代码。
- Android：需要统一包结构、应用标识、Manifest 分享入口及 `com.baleine.wwjing.bookmark/share` MethodChannel，并通过构建模式生成可区分安装的 kitchen/star 应用。
- Node API：复用现有认证后的 `GET /api/bookmarks/random?space=cookie` 和元数据接口；若现有返回契约不足，仅做兼容性补充，不新增数据库表。
- 数据：继续使用现有 `cookie` 与 `star` 收藏空间，不迁移或合并用户收藏数据。
- 依赖：不引入新的 Flutter 第三方包；复用现有 `http`、`provider`、`url_launcher` 与 Android Intent 实现。
