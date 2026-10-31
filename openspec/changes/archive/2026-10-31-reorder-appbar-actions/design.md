# Design

## Context

AppBar 布局优化与当前所在目录（`selectedFolderId`）的上下文穿透。详见 `proposal.md`。

## Goals / Non-Goals

**Goals:**

1. **AppBar 重新布局**：
   - 标题区：`Row(mainAxisSize: MainAxisSize.min, children: [Text(title), if (supportsRandom) RandomButton])`
   - 操作区：`actions: [AddButton, EditButton]`
2. **随机弹窗自适应预选**：
   - 修改 `showRandomFoldersFilterDialog`，接收 `String? currentFolderId` 参数。
   - 若 `currentFolderId != null`，初始选中的 ID 集合为 `{currentFolderId}`；
   - 否则保留全选行为。
3. **新建表单自适应预选**：
   - 点击加号按钮时，调用 `state.openDraftInFolder(state.selectedFolderId)` 或直接给草稿传入当前选中的 `selectedFolderId`。

## Decisions

- 在 `home_page.dart` 中：
  ```dart
  void _openCreateDraft() {
    final state = context.read<AppState>();
    final currentFolder = state.selectedFolderId;
    if (currentFolder != null) {
      state.openDraftInFolder(currentFolder);
    } else {
      state.openDraft();
    }
  }
  ```
- 随机弹窗逻辑：
  ```dart
  final selected = await showRandomFoldersFilterDialog(
    context: context,
    state: state,
    initialFolderId: state.selectedFolderId,
  );
  ```
