import 'package:flutter/material.dart';

import '../models/bookmark.dart';
import '../state/app_state.dart';

Future<List<String>?> showRandomFoldersFilterDialog({
  required BuildContext context,
  required AppState state,
}) {
  return showDialog<List<String>?>(
    context: context,
    builder: (context) => _RandomFoldersFilterDialog(state: state),
  );
}

class _RandomFoldersFilterDialog extends StatefulWidget {
  const _RandomFoldersFilterDialog({required this.state});

  final AppState state;

  @override
  State<_RandomFoldersFilterDialog> createState() =>
      _RandomFoldersFilterDialogState();
}

class _RandomFoldersFilterDialogState
    extends State<_RandomFoldersFilterDialog> {
  late final Set<String> allFolderIds = widget.state.folders
      .map((f) => f.id)
      .toSet();
  late Set<String> selectedIds;

  @override
  void initState() {
    super.initState();
    final saved = widget.state.selectedRandomFolderIds;
    if (saved == null || saved.isEmpty) {
      // 默认选择所有目录
      selectedIds = Set.from(allFolderIds);
    } else {
      // 过滤掉已被删除的无效目录
      selectedIds = saved.where(allFolderIds.contains).toSet();
      if (selectedIds.isEmpty) {
        selectedIds = Set.from(allFolderIds);
      }
    }
  }

  void _toggleSelectAll() {
    setState(() {
      if (selectedIds.length == allFolderIds.length) {
        selectedIds.clear();
      } else {
        selectedIds = Set.from(allFolderIds);
      }
    });
  }

  void _toggle(String id) {
    setState(() {
      if (selectedIds.contains(id)) {
        selectedIds.remove(id);
      } else {
        selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final nodes = flattenFolderTree(widget.state.folderTree).toList();
    final isAllSelected =
        allFolderIds.isNotEmpty && selectedIds.length == allFolderIds.length;

    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('选择随机目录范围')),
          TextButton(
            key: const Key('random-filter-select-all'),
            onPressed: allFolderIds.isEmpty ? null : _toggleSelectAll,
            child: Text(isAllSelected ? '全不选' : '全选'),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        height: MediaQuery.sizeOf(context).height * 0.5,
        child: nodes.isEmpty
            ? const Center(child: Text('暂无可选择的收藏目录'))
            : Card.outlined(
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: nodes.length,
                  itemBuilder: (context, index) {
                    final node = nodes[index];
                    final checked = selectedIds.contains(node.folder.id);
                    return Padding(
                      padding: EdgeInsets.only(left: (node.depth - 1) * 16.0),
                      child: CheckboxListTile(
                        key: Key('random-folder-checkbox-${node.folder.id}'),
                        value: checked,
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -4),
                        minTileHeight: 40,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                        ),
                        secondary: const Icon(Icons.folder_outlined, size: 20),
                        title: Text(
                          node.folder.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onChanged: (_) => _toggle(node.folder.id),
                      ),
                    );
                  },
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          key: const Key('random-filter-confirm'),
          icon: const Icon(Icons.casino_outlined, size: 18),
          label: const Text('开始随机'),
          onPressed: () {
            // 如果全选或全不选，返回空列表代表“不限制/全目录”，否则返回具体 ID
            if (selectedIds.isEmpty ||
                selectedIds.length == allFolderIds.length) {
              Navigator.pop(context, <String>[]);
            } else {
              Navigator.pop(context, selectedIds.toList());
            }
          },
        ),
      ],
    );
  }
}
