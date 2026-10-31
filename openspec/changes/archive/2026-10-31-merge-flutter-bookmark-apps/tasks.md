# Tasks

## 1. 统一工程与模式配置

- [x] 1.1 对比 `source/flutter_kitchen/` 与 `source/flutter_star/` 的 Dart、测试、Android 配置和资源差异，记录需要保留的差异并以较完整实现创建 `source/flutter_bookmark/`；验证新目录包含两侧现有共享能力对应的源文件和测试。
- [x] 1.2 在统一工程实现严格的 `APP_TYPE=kitchen|star` 编译期配置，集中提供应用名称、收藏空间和模式能力，将 API 客户端的硬编码 `cookie` 改为配置注入；通过单元测试验证 kitchen 映射到 `cookie`、star 映射到 `star`，缺失或非法值明确失败。
- [x] 1.3 更新启动入口、状态注入和页面标题以使用模式配置，并确认登录、分享、剪贴板、目录、收藏和搜索不再包含 kitchen/star 的散落硬编码；运行 `flutter analyze` 和现有 Flutter 测试验证共享行为无回退。
- [x] 1.4 更新统一工程 README，写明 kitchen/star 的运行与构建命令、`APP_TYPE` 约束、API 地址覆盖方式及旧安装需要重装登录；逐条核对示例命令包含匹配的 flavor 和 `--dart-define`。

## 2. Android 双模式构建与原生通道

- [x] 2.1 在单一 Android 工程配置 kitchen/star product flavors、不同 applicationId、应用标签和分享入口资源，并统一 Kotlin 包到 `com.baleine.wwjing.bookmark`；分别构建两种 debug APK，验证产物 applicationId 不同且可同时安装。
- [x] 2.2 将 Flutter 和 `MainActivity` 的 MethodChannel 统一为 `com.baleine.wwjing.bookmark/share`，保留指定包名 `ACTION_VIEW`、打开 App 首页和系统分享接收能力；通过 Android/Flutter channel 测试或设备 smoke test 验证两个 flavor 都能接收分享并调用原生打开方法。
- [x] 2.3 增加 flavor 与 `APP_TYPE` 配对校验，避免 kitchen flavor 以 star 配置运行或反之；用一组匹配构建成功和一组故意错配构建失败验证错误信息清晰。

## 3. kitchen 随机推荐

- [x] 3.1 在 `ApiClient` 和状态层接入认证后的 `GET /api/bookmarks/random?space=cookie`，将对象或空结果映射为 `BookmarkItem?` 并复用 401 处理；使用 fake HTTP 测试覆盖成功、空响应、服务端错误和未授权。
- [x] 3.2 从主页收藏行提取共享 `BookmarkItemCard`，以参数控制 checkbox、拖拽和操作菜单，保持现有列表行为不变；Widget 测试验证普通编辑列表仍显示选择与操作能力，精简模式只显示封面、标题和来源。
- [x] 3.3 仅在 kitchen 主页增加防重复点击的随机按钮和“今天吃什么”低高度弹窗，弹窗只放一个精简链接卡片并处理空结果和失败提示；Widget 测试验证 kitchen 显示按钮、star 隐藏按钮、弹窗非全屏且没有 checkbox/操作菜单。
- [x] 3.4 将随机卡片点击连接到统一链接打开入口；使用注入的 launcher/fake channel 验证点击使用随机条目的已保存 `sourceUrl`，并在无法打开时保留弹窗或页面且显示错误提示。

## 4. 平台链接跳转与小红书保存

- [x] 4.1 将平台识别和内容 ID 提取整理为可测试的纯策略，覆盖 Bilibili 完整/短链及 BV/av、小红书 discovery/item/explore/login redirectPath、抖音 video/note/share 路径；通过表驱动单元测试验证 host 精确匹配、ID 提取和未知平台回退。
- [x] 4.2 实现 Bilibili 的 HTTPS、Deep Link、App 首页顺序，小红书的 `xhsdiscover`、完整 HTTPS、App 首页顺序，以及抖音的 `snssdk1128`、App 首页顺序；使用 fake MethodChannel 验证每个平台成功短路、失败递进及 App 未安装后才回退系统外部链接。
- [x] 4.3 在收藏表单提交前识别 `xhslink.cn`/`xhslink.com`，重新调用元数据接口并只接受有效完整小红书 `finalUrl`，原样保留路径和查询参数；测试覆盖成功替换、参数保留、解析失败阻止保存、表单内容保留和完整 URL 直接保存。
- [x] 4.4 对照已启动的 3000 端口 Node 服务执行小红书元数据和随机接口 smoke test，确认 `finalUrl`、随机对象及空结果形态与 Flutter 解析一致；若实际契约不同，只做兼容修正并同步更新 `source/server-node` 对应测试和 `README.http`。

## 5. 迁移收尾与集成验证

- [x] 5.1 在统一工程通过 `flutter analyze`、全部单元/Widget 测试以及 kitchen/star 两种 debug 构建后，删除 `source/flutter_kitchen/` 与 `source/flutter_star/`；验证仓库只保留 `source/flutter_bookmark/` 作为 Flutter 收藏客户端且无脚本或文档引用旧目录。
- [x] 5.2 在 Android Pad 分别安装两种 flavor，使用同一账号验证原有 `cookie`/`star` 数据可见、分享和剪贴板入口可用、star 无随机按钮、kitchen 随机弹窗和卡片跳转可用，并记录 Bilibili、小红书、抖音实机结果。
- [x] 5.3 按项目规则更新受影响的模块规格及历史版本、统一工程 `build.json` 的当前时间与模型名、HTML BUILD_TIME（若本次涉及 HTML）和接口文档（若接口发生变化）；检查版本记录和生成信息完整且未修改无关模块。

## Workflow follow-up

- 实现和评审完成后归档该 OpenSpec 变更，并确认 `bookmark-app-modes` 主规格生成成功。
