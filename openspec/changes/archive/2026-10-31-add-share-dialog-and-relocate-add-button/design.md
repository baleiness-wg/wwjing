# Design

## Context

针对用户反馈的两个交互体验痛点进行改进：
1. 编辑表单打开时，若外部传入分享链接，原逻辑容易被覆盖或无明显响应；
2. 页面中的可拖拽悬浮主操作按钮占据空间并遮挡列表，需收敛至右上角 AppBar。

## Goals / Non-Goals

**Goals:**

- **新分享链接确认拦截**：在 `AppState` 或 `HomePage` 检测到新分享草稿时，如果 `state.draft != null`（表示表单当前已在编辑状态），弹出标准 Material 3 对话框，询问用户“检测到新分享链接，是否放弃当前编辑并切换？”。
  - 用户确认：关闭弹窗，以新草稿覆盖当前草稿并触发元数据识别；
  - 用户取消：清空新传入的分享缓存，保持原表单不变。
- **主页新建收藏按钮位置迁移**：
  - 移除原 `DraggableFloatingActionButton` 相关层级与状态；
  - 在 `HomePage` 的 AppBar 右侧 actions 中，顺序排布：全部收藏按钮 -> **新建收藏加号按钮 (`IconButton(icon: Icon(Icons.add))`)** -> 今天吃什么随机按钮（kitchen 模式下）-> 退出登录按钮。

**Non-Goals:**

- 不改变表单内部字段验证与保存接口逻辑。

## Decisions

### 1. 新分享提示确认逻辑
- 在 `HomePage` 的 `AppState` 监听中，记录表单是否处于打开状态；
- 当有新的分享链接触发 `handleSharedLink` 时，检查当前是否已有正在编辑的 draft：
  - 若 `draft == null`：直接打开表单（既有逻辑）；
  - 若 `draft != null`：调用 `showDialog` 显示确认框，确认后调用 `state.openDraft(newDraft)` 刷新表单内容。

### 2. AppBar 按钮布局排列
- 在 `HomePage` 的 `AppBar.actions` 列表中，紧跟“全部收藏”右侧添加：
  ```dart
  IconButton(
    icon: const Icon(Icons.add),
    tooltip: '收藏链接',
    onPressed: _openCreateForm,
  )
  ```
- 移除原先在 `Stack` 底部的可拖动悬浮 FAB。
