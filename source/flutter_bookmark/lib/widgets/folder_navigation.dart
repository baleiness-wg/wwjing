import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bookmark.dart';
import '../state/app_state.dart';

class FolderNavigation extends StatelessWidget {
  const FolderNavigation({super.key, this.closeAfterSelection = false});

  final bool closeAfterSelection;

  Future<void> _select(
    BuildContext context,
    BookmarkView view, [
    String? folderId,
  ]) async {
    await context.read<AppState>().selectView(view, folderId);
    if (closeAfterSelection && context.mounted) Navigator.pop(context);
  }

  Future<String?> _askName(
    BuildContext context, {
    String initial = '',
    String title = '新建收藏夹',
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
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
      final name = await _askName(context, title: '新增子目录');
      if (name?.isNotEmpty == true) await state.createFolder(name!, folder.id);
    } else if (action == 'move') {
      final parentId = await showDialog<String?>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('移动目录到'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, ''),
              child: const Text('根目录'),
            ),
            for (final node in flattenFolderTree(state.folderTree))
              if (node.folder.id != folder.id)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, node.folder.id),
                  child: Padding(
                    padding: EdgeInsets.only(left: (node.depth - 1) * 12.0),
                    child: Text(node.folder.name),
                  ),
                ),
          ],
        ),
      );
      if (parentId != null) {
        await state.moveFolder(folder, parentId.isEmpty ? null : parentId);
      }
    } else if (action == 'up') {
      await state.reorderFolder(folder, -1);
    } else if (action == 'down') {
      await state.reorderFolder(folder, 1);
    } else if (action == 'rename') {
      final name = await _askName(context, initial: folder.name, title: '重命名');
      if (name?.isNotEmpty == true) await state.renameFolder(folder, name!);
    } else if (action == 'delete') {
      await state.deleteFolder(folder);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final nodes = flattenFolderTree(state.folderTree).toList();
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(
              '微微鲸收藏',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
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
                  tooltip: '新建根目录',
                  onPressed: () async {
                    final name = await _askName(context);
                    if (name?.isNotEmpty == true && context.mounted) {
                      await context.read<AppState>().createFolder(name!, null);
                    }
                  },
                  icon: const Icon(Icons.create_new_folder_outlined),
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
                    selected:
                        state.view == BookmarkView.folder &&
                        state.selectedFolderId == node.folder.id,
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
                      onSelected: (action) =>
                          _folderAction(context, node.folder, action),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'bookmark', child: Text('添加收藏')),
                        PopupMenuItem(value: 'child', child: Text('新增子目录')),
                        PopupMenuItem(value: 'move', child: Text('移动目录')),
                        PopupMenuItem(value: 'up', child: Text('向前排序')),
                        PopupMenuItem(value: 'down', child: Text('向后排序')),
                        PopupMenuItem(value: 'rename', child: Text('重命名')),
                        PopupMenuItem(value: 'delete', child: Text('删除')),
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
