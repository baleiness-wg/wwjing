# Proposal

## Why

当前统一客户端登录页只支持用户名密码登录，缺少注册新账号的直接入口，导致新用户必须依赖接口工具先行注册；同时，应用品牌需要从“微微鲸厨房”升级为更具特色的“疯狂的厨房”，通用收藏品牌由“微微鲸收藏”更名为“鲸界”，并配以贴合烹饪与鲸鱼主题的全新 App 图标。

## What Changes

- 在客户端登录页增加注册入口与注册流程，支持输入用户名和密码直接注册并自动完成登录。
- 将 kitchen 模式应用名称由“微微鲸厨房”正式更名为“疯狂的厨房”，包括应用标题、Android label 和相关文档展示。
- 将 star 模式应用名称由“微微鲸星标”及原侧栏/登录通用名称“微微鲸收藏”更名为“鲸界”。
- 分别为两个 Android flavor（`kitchen` 和 `star`）提供专属的各分辨率 `ic_launcher` 图标资源：
  - `kitchen`（疯狂的厨房）：做饭/厨房主题图标（厨师帽、餐具与烹饪元素）。
  - `star`（鲸界）：鲸鱼主题图标（蓝白主调的跃水/深海鲸鱼轮廓）。
- 登录页与侧栏头部展示的品牌名称与图标图标与当前模式/全新品牌保持一致。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `bookmark-app-modes`: 统一客户端的登录/注册认证入口、应用品牌命名与各模式专属图标资产规范。

## Impact

- Flutter 端修改 `lib/config/app_config.dart`、`lib/services/api_client.dart`、`lib/state/app_state.dart`、`lib/widgets/login_page.dart`、`lib/widgets/folder_navigation.dart`。
- Android 端修改 `android/app/build.gradle.kts` 的 flavor label，并在 `src/kitchen/res` 和 `src/star/res` 下分别放置不同密度的烹饪与鲸鱼 launcher 图标。
- 更新受影响的 Flutter Widget/单元测试，确保注册交互、模式名称和双 flavor 构建通过。
- 同步更新模块规格 `specs/bookmark-app-modes/spec.md` 与构建信息 `build.json`。
