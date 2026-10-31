# Tasks

## 1. 登录注册功能支持

- [x] 1.1 在 `ApiClient` 中增加 `register(username, password)` 方法，并在 `AppState` 中实现 `register` 并自动登录；编写单元测试验证正常注册登录与错误处理。
- [x] 1.2 在 `LoginPage` 中添加“注册新账号”按钮、注册表单输入验证及调用流程；通过 Widget 测试验证注册成功跳转与错误提示展示。

## 2. 应用品牌与名称重命名

- [x] 2.1 修改 `AppConfig`、`build.gradle.kts` 及 README，将 kitchen 模式更名为“疯狂的厨房”，star 模式更名为“鲸界”。
- [x] 2.2 修改侧栏抽屉及登录页展示名称，使用当前模式品牌名称（“疯狂的厨房”或“鲸界”），去除旧“微微鲸收藏”硬编码。
- [x] 2.3 更新 `app_config_test.dart`、`responsive_layout_test.dart` 中关于应用名称的测试断言。

## 3. 定制做饭与鲸鱼应用图标

- [x] 3.1 准备符合做饭/厨房主题的各分辨率（mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi）图标资源并放入 `android/app/src/kitchen/res/`。
- [x] 3.2 准备符合鲸鱼主题的各分辨率（mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi）图标资源并放入 `android/app/src/star/res/`。

## 4. 验证与版本更新

- [x] 4.1 运行 `dart format`、`flutter analyze` 与全量单元/Widget 测试确保全部通过。
- [x] 4.2 执行 kitchen 和 star 两种 flavor 的 debug APK 构建并校验产物中的 app label 与图标。
- [x] 4.3 更新 `build.json`、`main.dart` 中的 BUILD_TIME 以及模块规格说明 `specs/bookmark-app-modes/spec.md`。

## Workflow follow-up

- 实施与评审完毕后归档变更。
