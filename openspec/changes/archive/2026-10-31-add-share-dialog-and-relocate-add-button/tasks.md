# Tasks

## 1. 主页 AppBar 收藏加号按钮迁移

- [x] 1.1 在 `source/flutter_bookmark/lib/widgets/home_page.dart` 中，移除底部的可拖拽悬浮 FAB 逻辑与层级。
- [x] 1.2 在 `home_page.dart` 的 AppBar 顶部操作栏中，在全部收藏右侧、随机推荐按钮左侧添加新建收藏加号按钮（`IconButton(icon: Icon(Icons.add))`）。
- [x] 1.3 更新并编写相关 Widget 测试验证 AppBar 加号按钮展示与打开表单行为。

## 2. 编辑状态下新分享链接确认弹窗

- [x] 2.1 在 `home_page.dart` 或 `app_state.dart` 中增加对编辑中接收新分享链接的拦截判断。
- [x] 2.2 当表单处于编辑中时收到新链接，弹出 Material 3 确认对话框，用户确认则替换为新链接并触发识别，取消则保留当前编辑。
- [x] 2.3 编写 Widget 测试验证新分享链接确认弹窗与切换行为。

## 3. 全量测试与规范同步

- [x] 3.1 运行 `flutter test` 和 `flutter analyze` 确保所有用例通过。
- [x] 3.2 更新构建元数据及模块规格说明。

## Workflow follow-up

- 完成实施后评审并归档变更。
