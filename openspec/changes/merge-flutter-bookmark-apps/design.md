# Design

## Context

参见 `proposal.md` 的动机。当前 `source/flutter_kitchen/` 与 `source/flutter_star/` 的 Dart 结构、依赖、页面和测试基本一致，但硬编码了不同的应用标题、`cookie`/`star` 空间、Android namespace/applicationId、Kotlin 包路径和 MethodChannel。Node 已有按 `space` 隔离的收藏接口、`GET /api/bookmarks/random` 随机接口及元数据重定向解析能力；合并应复用这些契约，不迁移 PostgreSQL 数据。

现有平台跳转代码仅覆盖抖音 Deep Link，其余已知平台直接尝试 HTTPS；目标实现还需补齐 Bilibili 备用 Deep Link、小红书笔记 Deep Link，以及保存前将小红书短链解析为完整 URL。Flutter 端继续运行于 Android Pad，且不增加第三方依赖。

## Goals / Non-Goals

**Goals:**

- 让 kitchen 与 star 从同一 `source/flutter_bookmark/` 源码构建，模式差异集中在一个不可变配置边界。
- 生成可区分且可同时安装的 Android kitchen/star 应用，同时让两者使用同一个原生跳转实现和 MethodChannel 协议。
- 将收藏条目卡片提取为可配置的共享组件，使主页列表与随机弹窗视觉一致而交互能力不同。
- 复用现有随机和元数据接口，保持认证、用户隔离及 `cookie`/`star` 数据空间不变。
- 以单元和 Widget 测试覆盖模式映射、随机交互、小红书 URL 解析提交以及平台 URI/包名选择。

**Non-Goals:**

- 不合并 `cookie` 与 `star` 的服务端数据，也不修改已有收藏记录的空间。
- 不增加 iOS、Web 或桌面构建目标。
- 不为随机推荐增加权重、历史去重、标签筛选或推荐算法。
- 不保证目标第三方 App 内部对失效 Token、账号校验或内容下架的处理结果。

## Decisions

### 1. 使用编译期配置对象作为唯一模式来源

通过 `String.fromEnvironment('APP_TYPE')` 解析模式，并映射到不可变配置：显示名称、收藏 `space`、Android flavor 名称及允许的模式功能。Dart 代码不再散布字符串比较，API 客户端由配置注入 `space`，主页通过配置能力位决定是否显示随机入口。未知或缺失模式在开发启动时抛出清晰错误；构建脚本和 README 中所有示例都显式传入 `APP_TYPE`。

替代方案是运行时选择模式或保留两个入口文件。运行时选择会允许单个安装访问两个空间且弱化应用身份隔离；两个入口文件仍会复制启动配置，因此不采用。

### 2. Android 使用 product flavors 区分可安装应用

在单一 Android 工程中定义 `kitchen` 和 `star` product flavor，为两者配置不同 `applicationId`、应用标签及必要资源，使其可在同一设备共存。Dart 的 `APP_TYPE` 与 Gradle flavor 必须配对，文档使用明确命令，例如 kitchen 模式指定 kitchen flavor 并传入 `--dart-define=APP_TYPE=kitchen`；测试验证模式映射，构建验证捕获错配。

原生 Kotlin 代码统一放在 `com.baleine.wwjing.bookmark` 包下，Flutter 与 Android 共用固定 MethodChannel `com.baleine.wwjing.bookmark/share`。应用身份由 flavor 负责，而不是通过 channel 名称区分。

替代方案是每次构建动态改写 Gradle 文件，容易产生不可复现产物；共用同一 applicationId 则无法并存且会覆盖旧安装，因此不采用。

### 3. 从当前较完整实现建立新目录，再删除旧工程

实现时比较两个工程而不是直接假设完全相同，以包含测试、Android 配置及尚未同步的修复为准建立 `source/flutter_bookmark/`。先使统一工程的两种模式通过测试和 Android 构建，再移除旧目录，避免迁移中途失去可比对基线。

旧 applicationId 的已有安装不会自动升级到新的 flavor 标识，用户需安装新产物；服务端数据不受影响，重新登录后即可读取原空间。若保留旧 applicationId 作为其中一个 flavor，会导致命名不对称且增加未来维护成本，因此统一采用 bookmark 命名空间并把重装要求写入迁移说明。

### 4. 随机功能直接复用认证 API

API 客户端增加获取随机收藏的方法，固定由 kitchen 配置提交 `space=cookie`，将现有响应映射为 `BookmarkItem?`。主页维护一次请求的 loading 状态，避免重复点击并在成功后打开弹窗；`null`、异常和 401 分别进入空结果、错误提示和既有未授权流程。star 模式没有调用入口。

随机弹窗采用内容自适应 `Dialog`/`AlertDialog`，设置最大宽度和受限高度，不使用全屏 bottom sheet。一个共享 `BookmarkItemCard` 组件接收选择、拖拽和操作菜单等可选能力；列表启用现有能力，随机弹窗全部关闭，只保留点击打开链接。

替代方案是在客户端拉取整页后随机，会受分页影响、浪费网络且分布不完整，因此使用服务端 `ORDER BY RANDOM() LIMIT 1` 的现有接口。

### 5. 平台跳转拆分为纯解析策略与原生执行

Dart 层根据规范化 host/path 生成有序跳转尝试，纯函数负责提取 Bilibili BV/av、小红书笔记 ID、抖音数字 ID，便于无设备测试。Android MethodChannel 继续提供指定 package 的 `ACTION_VIEW` 和打开 App 首页能力。

- Bilibili：完整 HTTPS 指定包名，失败后 `bilibili://video/{标识}`，再打开首页。
- 小红书：`xhsdiscover://item/{ID}`，失败后完整 HTTPS 指定包名，再打开首页。
- 抖音：`snssdk1128://aweme/detail/{ID}`；无 ID 或失败后打开首页。
- 未识别平台：直接走系统外部 HTTP/HTTPS 处理。

只有目标 App 不可用或所有已知平台尝试失败时才回退原始外部链接。这样避免浏览器抢占已识别平台，又保留未安装 App 时的可用性。

### 6. 小红书短链在提交阶段强制解析

表单自动元数据识别可以继续用于预填，但保存动作必须再次检查当前 `sourceUrl`，防止用户在自动识别后修改链接或首次请求尚未完成。若 host 为 `xhslink.cn`/`xhslink.com`，保存前调用元数据接口，验证 `finalUrl` 是受支持的小红书完整页面 URL，然后以完整字符串替换草稿并提交，不重建查询字符串。

解析失败时保留表单并阻止短链提交。该选择牺牲了元数据服务不可用时保存短链的能力，但保证数据库中的小红书记录可用于内容直达，符合给定平台约束。

## Risks / Trade-offs

- [Gradle flavor 与 `APP_TYPE` 可能错配] → 提供成对构建命令，加入构建时校验，并分别执行两种模式的 debug 构建。
- [删除旧工程后丢失某一侧独有修复] → 迁移前做目录差异核对，以行为测试和关键文件清单确认合并覆盖范围，再删除旧目录。
- [新 applicationId 无法覆盖旧安装] → 在 README 明确需要重装和重新登录；保留服务端空间，避免数据迁移。
- [`ORDER BY RANDOM()` 随数据增长变慢] → 当前复用既有实现；若实际数据量出现性能问题，另立变更设计采样策略。
- [第三方 App Deep Link 随版本变化] → 保留 HTTPS、App 首页和系统外部链接的分层回退，并以纯策略测试固定当前契约。
- [小红书 Token 过期或账号校验] → 完整保存服务端解析 URL 和查询参数，不承诺绕过第三方 App 自身校验。

## Migration Plan

1. 对比两个现有 Flutter 工程，建立 `source/flutter_bookmark/` 并统一 package、依赖、测试与共享 Dart 代码。
2. 增加模式配置和 Android product flavors，先验证 kitchen/star 分别可运行、可并存并访问原有空间。
3. 接入随机弹窗、共享卡片和完整平台跳转策略，补齐小红书保存前解析。
4. 运行 Dart 分析、单元/Widget 测试及两种 flavor 的 Android debug 构建，并在设备上验证分享接收和三平台跳转。
5. 验证通过后移除 `source/flutter_kitchen/` 与 `source/flutter_star/`，更新统一工程 README、`README.http`（若接口说明发生变化）和 `build.json`。

回滚时恢复两个旧工程并停止分发统一工程产物；服务端接口和数据未迁移，因此无需数据库回滚。
