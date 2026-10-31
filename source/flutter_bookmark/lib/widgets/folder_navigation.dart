import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../models/bookmark.dart';
import '../state/app_state.dart';
import 'app_popup_menu.dart';
import 'folder_picker_dialog.dart';

class FolderNavigation extends StatelessWidget {
  const FolderNavigation({
    super.key,
    this.closeAfterSelection = false,
    this.appConfig,
  });

  final bool closeAfterSelection;
  final AppConfig? appConfig;

  Future<void> _select(
    BuildContext context,
    BookmarkView view, [
    String? folderId,
  ]) async {
    await context.read<AppState>().selectView(view, folderId);
    if (closeAfterSelection && context.mounted) Navigator.pop(context);
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
    } else if (action == 'delete') {
      await state.deleteFolder(folder);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final nodes = flattenFolderTree(state.folderTree).toList();
    final effectiveAppName =
        appConfig?.appName ??
        (const String.fromEnvironment('APP_TYPE').isNotEmpty
            ? AppConfig.current.appName
            : '鲸界');
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(
              effectiveAppName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          ListTile(
            selected: state.view == BookmarkView.all,
            leading: const Icon(Icons.bookmarks_outlined),
            title: const Text('全部收藏'),
            onTap: () => _select(context, BookmarkView.all),
          ),
          ListTile(
            selected: state.view == BookmarkView.uncategorized,
            leading: const Icon(Icons.inbox_outlined),
            title: const Text('未分类'),
            onTap: () => _select(context, BookmarkView.uncategorized),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
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
                return Padding(
                  padding: EdgeInsets.only(left: (node.depth - 1) * 14.0),
                  child: ListTile(
                    dense: true,
                    visualDensity: const VisualDensity(vertical: -4),
                    minTileHeight: 40,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    selected:
                        state.view == BookmarkView.folder &&
                        state.selectedFolderId == node.folder.id,
                    selectedColor: Theme.of(context).colorScheme.primary,
                    selectedTileColor: Theme.of(context).colorScheme.primary
                        .withValues(alpha: 0.08),
                    leading: node.depth == 1
                        ? const Icon(Icons.folder_outlined)
                        : const SizedBox(width: 24),
                    title: Text(
                      node.folder.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () =>
                        _select(context, BookmarkView.folder, node.folder.id),
                    trailing: PopupMenuButton<String>(
                      tooltip: '目录操作',
                      icon: const Icon(Icons.more_vert),
                      onSelected: (action) =>
                          _folderAction(context, node.folder, action),
                      itemBuilder: (_) => [
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
                  ),
                );
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('退出登录'),
            onTap: () => state.logout(),
          ),
        ],
      ),
    );
  }
}
