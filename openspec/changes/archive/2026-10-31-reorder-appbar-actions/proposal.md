# Proposal

## Why

优化移动端收藏主页的按钮布局与目录上下文联动体验：
1. **按钮功能清晰分区**：
   - 随机按钮移到左侧标题右侧紧挨着（发现区）；
   - 新建加号按钮与批量编辑按钮集中在右上角（操作管理区）。
2. **上下文感知联动（核心痛点）**：
   - **随机抽取范围**：若当前在“全部收藏”，弹窗默认全选所有目录；若当前在某个特定文件夹内，弹窗默认**仅勾选当前文件夹**，不再需要用户手动反选。
   - **新建收藏归属**：若当前正在某个特定文件夹内点击新建，表单的归属目录**默认预选当前文件夹**，不再默认为“未分类”。

## What Changes

- **主页 AppBar 布局调整**：
  - 随机按钮移入标题栏，紧挨左侧标题文字；
  - 右上角 actions 并排保留新建加号按钮（`Icons.add`）与批量编辑按钮（`Icons.edit_outlined`）。
- **随机菜谱弹窗目录预选感知**：
  - 打开随机目录范围选择弹窗时，传入当前选中的 `selectedFolderId`。
  - 若 `selectedFolderId == null`（全部收藏视图），默认全选；
  - 若 `selectedFolderId != null`，默认初始勾选项仅为 `[selectedFolderId]`。
- **新建收藏表单目录预选感知**：
  - 点击新建加号按钮时，将当前选中的 `selectedFolderId` 自动作为新建草稿的 `folderId`。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `bookmark-app-modes`: 主页 AppBar 重新布局，且随机推荐与新建收藏按钮根据当前所在目录自动预选目录上下文。

## Impact

- `source/flutter_bookmark/lib/widgets/home_page.dart`
- `source/flutter_bookmark/lib/widgets/random_folders_filter_dialog.dart`
- 相关的 Widget 测试用例。
