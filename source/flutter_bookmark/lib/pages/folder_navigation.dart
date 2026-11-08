import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/app_popup_menu.dart';
import '../components/folder_picker_dialog.dart';
import '../constants/app_config.dart';
import '../stores/bookmark_state.dart';
import '../viewmodels/bookmark.dart';

class FolderNavigation extends StatefulWidget {
  const FolderNavigation({
    super.key,
    this.closeAfterSelection = false,
    this.appConfig,
  });

  final bool closeAfterSelection;
  final AppConfig? appConfig;

  @override
  State<FolderNavigation> createState() => _FolderNavigationState();
}

class _FolderNavigationState extends State<FolderNavigation> {
  final Set<String> _collapsedFolderIds = {};
  Set<String> _initializedFolderIds = {};
  String _initializedPinnedKey = '';
  String? _activeActionFolderId;

  Future<void> _select(
    BuildContext context,
    BookmarkView view, [
    String? folderId,
  ]) async {
    await context.read<AppState>().selectView(view, folderId);
    if (widget.closeAfterSelection && context.mounted) Navigator.pop(context);
  }

  Set<String> _folderAndDescendants(AppState state, String folderId) {
    final excluded = <String>{folderId};
    var changed = true;
    while (changed) {
      changed = false;
      for (final folder in state.folders) {
        if (folder.parentId != null &&
            excluded.contains(folder.parentId) &&
            excluded.add(folder.id)) {
          changed = true;
        }
      }
    }
    return excluded;
  }

  Future<void> _createFolder(
    BuildContext context,
    AppState state,
    String? parentId,
  ) async {
    final name = await showFolderNameDialog(
      context,
      title: parentId == null ? '新增根目录' : '新增子目录',
    );
    if (name?.isNotEmpty == true) await state.createFolder(name!, parentId);
  }

  Future<void> _folderAction(
    BuildContext context,
    BookmarkFolder folder,
    String action,
  ) async {
    final state = context.read<AppState>();
    if (action == 'bookmark') {
      state.openDraftInFolder(folder.id);
      return;
    }
    if (action == 'child') {
      await _createFolder(context, state, folder.id);
    } else if (action == 'move') {
      final parentId = await showFolderPicker(
        context: context,
        state: state,
        title: '移动目录到',
        selectedFolderId: folder.parentId,
        rootLabel: '根目录',
        excludedFolderIds: _folderAndDescendants(state, folder.id),
      );
      if (parentId != null) {
        await state.moveFolder(folder, parentId.isEmpty ? null : parentId);
      }
    } else if (action == 'up') {
      await state.reorderFolder(folder, -1);
    } else if (action == 'down') {
      await state.reorderFolder(folder, 1);
    } else if (action == 'rename') {
      final name = await showFolderNameDialog(
        context,
        initial: folder.name,
        title: '重命名目录',
      );
      if (name?.isNotEmpty == true) await state.renameFolder(folder, name!);
    } else if (action == 'pin') {
      await state.api.pinFolder(folder.id, !folder.pinned);
      await state.refresh();
    } else if (action == 'share') {
      final username = await showDialog<String>(
        context: context,
        builder: (dialogContext) => _ShareFolderDialog(
          folderId: folder.id,
          onSubmit: (value) => Navigator.pop(dialogContext, value),
        ),
      );
      if (username?.isNotEmpty == true) {
        await state.api.shareFolder(folder.id, username!);
        await state.refresh();
      }
    } else if (action == 'delete') {
      await state.deleteFolder(folder);
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    try {
      final values = await showDialog<List<String>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('修改密码'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(labelText: '当前密码'),
              ),
              TextField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(labelText: '新密码'),
              ),
              TextField(
                controller: confirm,
                obscureText: true,
                decoration: const InputDecoration(labelText: '确认新密码'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, [
                current.text,
                next.text,
                confirm.text,
              ]),
              child: const Text('确认修改'),
            ),
          ],
        ),
      );
      if (values == null || !context.mounted) return;
      if (values.any((value) => value.isEmpty)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('请填写完整密码信息')));
        return;
      }
      if (values[1] != values[2]) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('两次输入的新密码不一致')));
        return;
      }
      final state = context.read<AppState>();
      final changed = await state.changePassword(
        values[0],
        values[1],
        values[2],
      );
      if (changed && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('密码修改成功，请重新登录')));
      }
    } finally {
      current.dispose();
      next.dispose();
      confirm.dispose();
    }
  }

  List<FolderNode> _visibleNodes(List<FolderNode> roots) {
    final result = <FolderNode>[];
    void visit(FolderNode node) {
      result.add(node);
      if (!_collapsedFolderIds.contains(node.folder.id)) {
        for (final child in node.children) {
          visit(child);
        }
      }
    }

    for (final root in roots) {
      visit(root);
    }
    return result;
  }

  void _expandParentsOfPinned(AppState state) {
    final byId = {for (final folder in state.folders) folder.id: folder};
    for (final folder in state.folders.where((folder) => folder.pinned)) {
      var parentId = folder.parentId;
      while (parentId != null) {
        _collapsedFolderIds.remove(parentId);
        parentId = byId[parentId]?.parentId;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final currentIds = state.folders.map((folder) => folder.id).toSet();
    final pinnedKey = state.folders
        .where((folder) => folder.pinned)
        .map((folder) => folder.id)
        .join(',');
    if (_initializedFolderIds.length != currentIds.length ||
        !_initializedFolderIds.containsAll(currentIds) ||
        _initializedPinnedKey != pinnedKey) {
      _collapsedFolderIds.addAll(currentIds);
      _expandParentsOfPinned(state);
      _initializedFolderIds = currentIds;
      _initializedPinnedKey = pinnedKey;
    }
    final nodes = _visibleNodes(state.folderTree);
    final effectiveAppName =
        widget.appConfig?.appName ??
        (const String.fromEnvironment('APP_TYPE').isNotEmpty
            ? AppConfig.current.appName
            : '鲸界');
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Text(
              effectiveAppName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          ListTile(
            dense: true,
            visualDensity: const VisualDensity(vertical: -2),
            selected: state.view == BookmarkView.all,
            leading: const Icon(Icons.bookmarks_outlined),
            title: const Text('全部收藏'),
            onTap: () => _select(context, BookmarkView.all),
          ),
          ListTile(
            dense: true,
            visualDensity: const VisualDensity(vertical: -2),
            selected: state.view == BookmarkView.uncategorized,
            leading: const Icon(Icons.inbox_outlined),
            title: const Text('未分类'),
            onTap: () => _select(context, BookmarkView.uncategorized),
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '收藏夹',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  key: const Key('create-root-folder-button'),
                  tooltip: '新建根目录',
                  icon: const Icon(Icons.create_new_folder_outlined),
                  onPressed: () => _createFolder(context, state, null),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: nodes.length,
              itemBuilder: (context, index) {
                final node = nodes[index];
                final hasChildren = node.children.isNotEmpty;
                final actionActive = _activeActionFolderId == node.folder.id;
                return Padding(
                  padding: EdgeInsets.only(left: (node.depth - 1) * 14.0),
                  child: ListTile(
                    tileColor: node.folder.pinned
                        ? Colors.grey.shade200
                        : actionActive
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : null,
                    dense: true,
                    visualDensity: const VisualDensity(vertical: -4),
                    minTileHeight: 38,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    selected:
                        state.view == BookmarkView.folder &&
                        state.selectedFolderId == node.folder.id,
                    selectedColor: Theme.of(context).colorScheme.primary,
                    selectedTileColor: Theme.of(context).colorScheme.primary
                        .withValues(alpha: 0.08),
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(
                      node.folder.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () =>
                        _select(context, BookmarkView.folder, node.folder.id),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (node.folder.pinned)
                          const Icon(Icons.push_pin, size: 15),
                        if (hasChildren)
                          IconButton(
                            icon: Icon(
                              _collapsedFolderIds.contains(node.folder.id)
                                  ? Icons.chevron_right
                                  : Icons.expand_more,
                            ),
                            tooltip:
                                _collapsedFolderIds.contains(node.folder.id)
                                ? '展开目录'
                                : '收起目录',
                            onPressed: () => setState(() {
                              if (!_collapsedFolderIds.add(node.folder.id)) {
                                _collapsedFolderIds.remove(node.folder.id);
                              }
                            }),
                          ),
                        PopupMenuButton<String>(
                          tooltip: '目录操作',
                          icon: const Icon(Icons.more_vert),
                          position: PopupMenuPosition.under,
                           // Keep the menu close below the trailing icon without covering it.
                           offset: const Offset(-150, 8),
                          onOpened: () => setState(() {
                            _activeActionFolderId = node.folder.id;
                          }),
                          onCanceled: () => setState(() {
                            _activeActionFolderId = null;
                          }),
                          onSelected: (action) async {
                            await _folderAction(context, node.folder, action);
                            if (mounted) {
                              setState(() => _activeActionFolderId = null);
                            }
                          },
                          itemBuilder: (_) => [
                            appPopupMenuItem(
                              value: 'pin',
                              icon: Icons.push_pin_outlined,
                              label: node.folder.pinned ? '取消置顶' : '置顶目录',
                            ),
                            appPopupMenuItem(
                              value: 'share',
                              icon: Icons.share_outlined,
                              label: '共享目录',
                            ),
                            appPopupMenuItem(
                              value: 'bookmark',
                              icon: Icons.bookmark_add_outlined,
                              label: '添加收藏',
                            ),
                            appPopupMenuItem(
                              value: 'child',
                              icon: Icons.create_new_folder_outlined,
                              label: '新增子目录',
                            ),
                            appPopupMenuItem(
                              value: 'move',
                              icon: Icons.drive_file_move_outline,
                              label: '移动',
                            ),
                            appPopupMenuItem(
                              value: 'up',
                              icon: Icons.arrow_upward,
                              label: '向前排序',
                            ),
                            appPopupMenuItem(
                              value: 'down',
                              icon: Icons.arrow_downward,
                              label: '向后排序',
                            ),
                            appPopupMenuItem(
                              value: 'rename',
                              icon: Icons.edit_outlined,
                              label: '重命名',
                            ),
                            appPopupMenuItem(
                              value: 'delete',
                              icon: Icons.delete_outline,
                              label: '删除',
                              destructive: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          ListTile(
            leading: PopupMenuButton<String>(
              tooltip: '设置选项',
              icon: const Icon(Icons.settings_outlined),
              position: PopupMenuPosition.under,
              // The settings icon is on the left edge, so open to its right.
              offset: const Offset(48, 8),
              onSelected: (action) async {
                if (action == 'password') await _changePassword(context);
                if (action == 'logout') await state.logout();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'password', child: Text('修改密码')),
                PopupMenuItem(value: 'logout', child: Text('退出登录')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareFolderDialog extends StatefulWidget {
  const _ShareFolderDialog({required this.folderId, required this.onSubmit});

  final String folderId;
  final ValueChanged<String> onSubmit;

  @override
  State<_ShareFolderDialog> createState() => _ShareFolderDialogState();
}

class _ShareFolderDialogState extends State<_ShareFolderDialog> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _shares = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadShares();
  }

  Future<void> _loadShares() async {
    final state = context.read<AppState>();
    try {
      final shares = await state.api.getFolderShares(widget.folderId);
      if (mounted) {
        setState(() {
          _shares = shares;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('共享目录'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_loading)
              const LinearProgressIndicator()
            else if (_shares.isEmpty)
              const Align(alignment: Alignment.centerLeft, child: Text('暂未共享'))
            else
              ..._shares.map(
                (share) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${share['username'] ?? ''}'),
                  trailing: IconButton(
                    tooltip: '移除共享',
                    icon: const Icon(Icons.person_remove_outlined),
                    onPressed: () async {
                      await context.read<AppState>().api.removeFolderShare(
                        widget.folderId,
                        '${share['userId']}',
                      );
                      await _loadShares();
                    },
                  ),
                ),
              ),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: '添加用户名'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => widget.onSubmit(_controller.text.trim()),
          child: const Text('共享'),
        ),
      ],
    );
  }
}
