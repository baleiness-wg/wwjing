# Tasks

## 1. AppBar 按钮重新布局与目录上下文联动

- [x] 1.1 在 `source/flutter_bookmark/lib/widgets/home_page.dart` 中，将随机推荐按钮移入 title 区域，紧贴标题文字右侧；actions 集中并排新建加号按钮（`Icons.add`）和编辑按钮（`Icons.edit_outlined`）。
- [x] 1.2 在 `home_page.dart` 和 `random_folders_filter_dialog.dart` 中，实现根据当前目录上下文自适应预选：若在全部收藏则默认全选，若在某文件夹则默认仅勾选当前文件夹。
- [x] 1.3 在点击新建加号按钮时，若当前处于某文件夹下，新建表单的归属目录默认预选为该文件夹。
- [x] 1.4 更新并补充相关 Widget 测试用例。

## 2. 全量验证与更新

- [x] 2.1 运行 `flutter test` 和 `flutter analyze` 确保所有用例通过。
- [x] 2.2 更新构建元数据并归档变更。

## Workflow follow-up

- 完成实施后评审并归档变更。
