# Design

## Context

现有 `source/flutter` 是单一 Android Flutter 工程，已包含 JWT 登录、安全存储、收藏夹、分享文本解析、标题识别、封面展示和外部 App 跳转。Node 服务的收藏接口目前没有应用空间或标签概念，收藏夹与收藏条目通过用户归属隔离。具体行为目标见 `proposal.md` 和三个 delta spec。

## Goals / Non-Goals

**Goals:**

- 将现有客户端稳定迁移为 `flutter_star`，保留原用户数据和原有行为。
- 新增 `flutter_kitchen`，复用通用基础能力但使用独立应用空间。
- 让服务端在数据库和每个 API 查询层都执行 `user_id + space` 隔离。
- 为 `cookie` 空间提供标签多选、标签维护和简单随机菜谱。
- 让标题识别、分享接收、外部 App 跳转和认证逻辑只维护一份共享实现。

**Non-Goals:**

- 不实现图片上传；封面继续使用已有 URL 字段和手动编辑能力。
- 不实现最近做过排除、饮食计划、营养分析、购物清单或菜谱结构化解析。
- 不改变 Web 端现有星标收藏页面的默认业务范围；空间字段接入后，Web 继续固定使用 `star`。

## Decisions

### 1. 通过 workspace 参数隔离服务端数据

在 `bookmark_folders`、`bookmark_items` 及新增标签表中增加 `space` 字段，允许值限定为 `star` 和 `cookie`。所有服务层查询必须把 `space` 作为内部参数传入，控制器从固定客户端配置或请求参数校验后使用，不接受任意用户空间字符串。

迁移既有数据时统一设置 `space = 'star'`，保证原客户端数据不改变。相比创建两套表，单表加空间字段能复用模型、索引和迁移逻辑，也方便未来增加第三个收藏 App。

### 2. Flutter 采用共享包加两个应用壳

将认证、API 基础请求、token store、分享服务、链接标题解析、外部 App 启动、通用收藏模型和目录组件抽至 `source/flutter_shared`；`source/flutter_star` 与 `source/flutter_kitchen` 使用 path dependency 或共享源码依赖。两个应用分别保留自己的 `AppState`、主题入口和页面组合。

不直接复制整个工程，因为复制会使后续修复分享解析和 Android Deep Link 时产生双份差异；也不把两个 App 合成一个运行时开关，因为用户需要独立安装图标和数据空间。

### 3. 客户端空间固定在应用配置中

共享 API 客户端接收不可变 `space` 参数。`flutter_star` 固定传 `star`，`flutter_kitchen` 固定传 `cookie`；服务端仍校验允许值和用户身份。移动端不提供空间切换入口，避免用户误把两个 App 的数据混在一起。

### 4. 标签使用用户空间内的多对多关系

新增 `bookmark_tags` 和 `bookmark_item_tags`：标签包含 `user_id`、`space`、名称和时间；关联表包含收藏条目与标签 ID，并对 `(item_id, tag_id)` 建唯一约束。标签删除只删除关联，不删除条目。条目创建/更新在同一事务中校验标签属于当前用户和 `cookie` 空间。

相比把标签编码到 JSONB，独立关系表可以稳定支持按标签查询、重命名和多选过滤，也不会破坏现有条目元数据字段。

### 5. 随机菜谱使用服务端随机单条查询

新增认证接口 `GET /api/bookmarks/random?space=cookie&folderId=&tagId=`，按用户、空间及可选目录/标签过滤后随机返回一条条目；无结果返回明确空状态。第一版使用数据库随机排序即可，不记录历史、不排除近期结果。这样不会受客户端分页当前页限制，且两个客户端未来都能复用随机能力。

### 6. 数据迁移与客户端身份迁移分阶段完成

先完成数据库空间迁移和服务端兼容接口，再将目录改名和 Android application ID 改为 `com.baleine.wwjing.star`，最后创建 cookie 工程。每一步都保留独立构建验证，避免同时发生路径、包名和 API 变化导致问题难以定位。

## Risks / Trade-offs

- [Risk] application ID 变化会让 Android 将 `flutter-star` 视为新安装 → 保留同账号云端数据，并在迁移说明中明确需要重新安装和登录；不删除旧 APK 数据直到验证完成。
- [Risk] 漏掉某个服务端查询的 `space` 条件造成跨应用数据泄露 → 为每个收藏夹、条目和标签模型查询增加空间参数，并添加跨空间测试。
- [Risk] path dependency 共享包让两个工程的构建路径更复杂 → 固定仓库内相对路径并在两个工程分别执行 `flutter pub get`、analyze、test 和 APK 构建。
- [Risk] 数据库随机查询在收藏数量很大时变慢 → 第一版限定为简单随机并记录性能边界，后续可改为随机 ID 采样，不改变接口契约。
- [Risk] 标签名称重复造成选择混乱 → 同一用户同一空间内对标签名称建立唯一约束，并在客户端显示明确重复错误。

## Migration Plan

1. 增加空间字段、默认值和索引；将现有收藏夹与条目标记为 `star`。
2. 增加标签表、关联表、标签 API 和随机 API，并完成用户/空间隔离测试。
3. 抽取共享 Flutter 包，复制现有工程为 `flutter-star`，更新包名、application ID、Intent channel 和应用名称。
4. 构建并验证 `flutter-star`，确认原有星标数据可读取，再创建 `flutter-cookie`。
5. 实现 cookie 页面、标签维护、标签筛选、分享保存和“今天做什么”随机入口。
6. 完成两个 APK、Node 服务、数据库迁移和跨空间验收后，再清理旧 `source/flutter` 路径；若迁移失败，回滚应用入口和代码目录，不回滚已写入的星标数据字段。

## Open Questions

无。标签名称唯一性、共享账号、空间隔离和第一版简单随机规则已根据用户确认固定。
