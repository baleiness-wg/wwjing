import 'dart:async';

import 'package:flutter/material.dart';

import '../stores/bookmark_state.dart';
import '../viewmodels/bookmark.dart';

List<String> _collectAllDescendants(
  List<BookmarkFolder> folders,
  String parentId,
) {
  final result = <String>[parentId];
  for (final folder in folders) {
    if (folder.parentId == parentId) {
      result.addAll(_collectAllDescendants(folders, folder.id));
    }
  }
  return result;
}

Future<List<String>?> showRandomFoldersFilterDialog({
  required BuildContext context,
  required AppState state,
  String? currentFolderId,
}) {
  return showDialog<List<String>?>(
    context: context,
    builder: (context) => _RandomFoldersFilterDialog(
      state: state,
      currentFolderId: currentFolderId,
    ),
  );
}

class _RandomFoldersFilterDialog extends StatefulWidget {
  const _RandomFoldersFilterDialog({required this.state, this.currentFolderId});

  final AppState state;
  final String? currentFolderId;

  @override
  State<_RandomFoldersFilterDialog> createState() =>
      _RandomFoldersFilterDialogState();
}

class _RandomFoldersFilterDialogState
    extends State<_RandomFoldersFilterDialog> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _folderKeys = {};
  late String _selectedId;
  Timer? _scrollTimer;
  int _scrollAttempts = 0;

  @override
  void initState() {
    super.initState();
    final folderIds = widget.state.folders.map((folder) => folder.id).toSet();
    _selectedId =
        widget.currentFolderId != null &&
            folderIds.contains(widget.currentFolderId)
        ? widget.currentFolderId!
        : 'all';
    _scheduleScrollToSelection();
  }

  List<FolderNode> _folderNodes() =>
      flattenFolderTree(widget.state.folderTree).toList();

  void _scrollToSelection() {
    if (!mounted || _selectedId == 'all' || _selectedId == 'uncategorized') {
      return;
    }
    final target = _folderKeys[_selectedId]?.currentContext;
    if (target == null) {
      _scheduleScrollToSelection();
      return;
    }
    Scrollable.ensureVisible(
      target,
      alignment: 0.5,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _scheduleScrollToSelection() {
    if (!mounted || _selectedId == 'all' || _selectedId == 'uncategorized')
      return;
    _scrollTimer?.cancel();
    if (_scrollAttempts >= 12) return;
    _scrollAttempts += 1;
    _scrollTimer = Timer(const Duration(milliseconds: 80), () {
      _scrollTimer = null;
      _scrollToSelection();
    });
  }

  void _select(String id) {
    setState(() {
      _selectedId = id;
      _scrollAttempts = 0;
    });
  }

  List<String> _selectedFolderIds() {
    if (_selectedId == 'all' || _selectedId == 'uncategorized') return [];
    return _collectAllDescendants(widget.state.folders, _selectedId);
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nodes = _folderNodes();
    return AlertDialog(
      title: const Text('选择随机目录范围'),
      content: SizedBox(
        width: 440,
        height: MediaQuery.sizeOf(context).height * 0.5,
        child: Card.outlined(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _buildOption(
                id: 'all',
                title: '全部收藏',
                icon: Icons.collections_bookmark_outlined,
              ),
              _buildOption(
                id: 'uncategorized',
                title: '灵感',
                icon: Icons.inbox_outlined,
              ),
              for (final node in nodes) _buildFolderOption(node),
            ],
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
          onPressed: () => Navigator.pop(context, _selectedFolderIds()),
        ),
      ],
    );
  }

  Widget _buildFolderOption(FolderNode node) {
    final key = _folderKeys.putIfAbsent(node.folder.id, GlobalKey.new);
    return Padding(
      key: key,
      padding: EdgeInsets.only(left: (node.depth - 1) * 16.0),
      child: _buildOption(
        id: node.folder.id,
        title: node.folder.name,
        icon: Icons.folder_outlined,
      ),
    );
  }

  Widget _buildOption({
    required String id,
    required String title,
    required IconData icon,
  }) {
    final selected = _selectedId == id;
    final colorScheme = Theme.of(context).colorScheme;
    const selectedBackground = Color(0xFFE2F0E8);
    const selectedForeground = Color(0xFF35614B);
    return Material(
      color: selected ? selectedBackground : Colors.transparent,
      child: InkWell(
        key: Key('random-folder-option-$id'),
        onTap: () => _select(id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? selectedForeground
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected ? selectedForeground : null,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, size: 20, color: selectedForeground),
            ],
          ),
        ),
      ),
    );
  }
}
