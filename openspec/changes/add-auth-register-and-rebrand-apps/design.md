# Design

## Context

统一客户端当前支持 `APP_TYPE=kitchen` 与 `APP_TYPE=star` 两个构建模式，分别绑定 `cookie` 与 `star` 收藏空间。服务端已有现成的 `/api/auth/register` 与 `/api/auth/login` 接口。当前登录界面 `LoginPage` 仅有登录按钮，未暴露注册入口；应用名称沿用了旧品牌“微微鲸厨房”和“微微鲸星标/微微鲸收藏”；Android 启动图标为未区分的默认通用图标。

## Goals / Non-Goals

**Goals:**

- 在 `LoginPage` 增加与登录对称的“注册”操作（使用二级或并列按钮样式，如 OutlinedButton/TextButton 或并排 Filled/Tonal 按钮），复用服务端 `/api/auth/register`。
- 注册成功后自动执行 `login` 并加载对应数据空间，避免用户额外手动再点一次登录。
- 重命名应用：
  - kitchen 模式：应用名称统一为“疯狂的厨房”（包含 AppConfig、Android flavor string label、README）。
  - star 模式：应用名称统一为“鲸界”（包含 AppConfig、Android flavor string label、README、侧栏标题）。
- 制作并放入两个 flavor 的独立 mipmap 图标集（mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi）：
  - `src/kitchen/res/mipmap-*`：做饭/厨师帽/烹饪锅铲主题。
  - `src/star/res/mipmap-*`：鲸鱼跃水/蓝色鲸鱼主题。
- 保持既有测试、Gradle flavor 防错校验以及 MethodChannel 行为不变。

**Non-Goals:**

- 不改变服务端 `/api/auth/register` 的校验逻辑或加盐哈希算法。
- 不增加复杂的验证码、邮箱绑定或密码重置流程。
- 不破坏现有测试体系，保持 100% 测试通过。

## Decisions

### 1. 登录页交互：登录为主操作，注册为次操作（或切换标签）

在现有 `FilledButton('登录')` 下方添加 `OutlinedButton('注册新账号')`。点击注册时先做前端非空校验，随后调用 `AppState.register(username, password)`。服务端注册成功后直接无缝调用登录并进入主页。如果注册报 409（用户名已存在），由 `AppState.error` 展示可读错误信息。

### 2. 品牌名称多处统一

- `AppConfig.kitchen.appName` -> `'疯狂的厨房'`
- `AppConfig.star.appName` -> `'鲸界'`
- `android/app/build.gradle.kts`:
  - `kitchen` flavor resValue -> `"疯狂的厨房"`
  - `star` flavor resValue -> `"鲸界"`
- `FolderNavigation` 抽屉标题：动态取 `AppConfig.current.appName`（或当前全局模式名称），使星标版显示“鲸界”，厨房版显示“疯狂的厨房”，彻底去除旧“微微鲸收藏”字样。

### 3. Android 图标分 flavor 隔离

Android Gradle 支持按 flavor 覆盖资源：
- `android/app/src/kitchen/res/mipmap-*/ic_launcher.png`
- `android/app/src/star/res/mipmap-*/ic_launcher.png`

通过独立生成符合做饭/厨房特征与鲸鱼特征的完整 5 种密度 PNG 图标（mdpi 48x48, hdpi 72x72, xhdpi 96x96, xxhdpi 144x144, xxxhdpi 192x192），由 Android 打包系统在不同 flavor 构建时自动合入最终 APK，免除动态脚本替换。

## Risks / Trade-offs

- [图标尺寸/格式不合规导致打包失败] -> 严格按 Android mipmap 规范尺寸（48, 72, 96, 144, 192）生成有效的 32 位 RGBA PNG 图标。
- [已有测试硬编码“微微鲸厨房”或“微微鲸星标”] -> 同步更新 `app_config_test.dart` 和 `responsive_layout_test.dart` 中的文本匹配断言。
