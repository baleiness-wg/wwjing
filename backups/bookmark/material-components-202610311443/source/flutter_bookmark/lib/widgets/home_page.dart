import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bookmark.dart';
import '../config/app_config.dart';
import '../services/link_launcher.dart';
import '../state/app_state.dart';
import 'bookmark_item_card.dart';
import 'folder_navigation.dart';

sealed class _DragEntry {
  const _DragEntry();
}

class _ItemDragEntry extends _DragEntry {
  const _ItemDragEntry(this.item);

  final BookmarkItem item;
}

class _FolderDragEntry extends _DragEntry {
  const _FolderDragEntry(this.folder);

  final BookmarkFolder folder;
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.appConfig,
    this.linkLauncher = const LinkLauncher(),
  });

  final AppConfig appConfig;
  final LinkLauncher linkLauncher;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _search = TextEditingController();
  double? _actionLeft;
  double? _actionTop;
  bool _actionDragged = false;
  bool _editMode = false;
  bool _randomBusy = false;
  final Set<String> _selectedItemIds = {};

  List<BookmarkFolder> _childFolders(AppState state) {
    if (state.view != BookmarkView.folder || state.selectedFolderId == null) {
      return const [];
    }
    return state.folders
        .where((folder) => folder.parentId == state.selectedFolderId)
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _move(BuildContext context, BookmarkItem item) async {
    final state = context.read<AppState>();
    final folderId = await showDialog<String?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('移动到'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('未分类'),
          ),
          for (final node in flattenFolderTree(state.folderTree))
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
    if (folderId != null && context.mounted) {
      await state.moveItem(item.id, folderId.isEmpty ? null : folderId);
    }
  }

  Future<void> _moveSelected(BuildContext context) async {
    final state = context.read<AppState>();
    final folderId = await showDialog<String?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('批量移动到'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('未分类'),
          ),
          for (final node in flattenFolderTree(state.folderTree))
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
    if (folderId == null || !context.mounted) return;
    await state.moveItems(_selectedItemIds, folderId.isEmpty ? null : folderId);
    if (context.mounted) setState(_selectedItemIds.clear);
  }

  Future<void> _deleteSelected(BuildContext context) async {
    final state = context.read<AppState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('批量删除收藏'),
        content: Text('确定删除已选择的 ${_selectedItemIds.length} 条收藏吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await state.deleteItems(_selectedItemIds);
    if (context.mounted) setState(_selectedItemIds.clear);
  }

  Future<void> _openLink(BuildContext context, BookmarkItem item) async {
    await widget.linkLauncher.open(context, item.sourceUrl);
  }

  Future<void> _showRandom(BuildContext context) async {
    if (_randomBusy) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _randomBusy = true);
    final state = context.read<AppState>();
    final item = await state.randomItem();
    if (!mounted) return;
    setState(() => _randomBusy = false);
    if (item == null) {
      final message = state.error ?? '暂无可推荐内容';
      messenger.showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    await showDialog<void>(
      context: navigator.context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('今天吃什么'),
        content: ConstrainedBox(
          key: const Key('random-bookmark-content'),
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 150),
          child: BookmarkItemCard(
            item: item,
            onTap: () => _openLink(dialogContext, item),
          ),
        ),
      ),
    );
  }

  Future<void> _openChildFolder(
    BuildContext context,
    BookmarkFolder folder,
  ) async {
    await context.read<AppState>().selectView(BookmarkView.folder, folder.id);
  }

  bool _isFolderDescendant(AppState state, String folderId, String targetId) {
    var currentId = state.folders
        .where((folder) => folder.id == targetId)
        .firstOrNull
        ?.parentId;
    while (currentId != null) {
      if (currentId == folderId) return true;
      currentId = state.folders
          .where((folder) => folder.id == currentId)
          .firstOrNull
          ?.parentId;
    }
    return false;
  }

  Future<void> _dropEntry(
    BuildContext context,
    _DragEntry entry,
    BookmarkFolder target,
  ) async {
    final state = context.read<AppState>();
    if (entry is _ItemDragEntry) {
      await state.moveItem(entry.item.id, target.id);
    } else if (entry is _FolderDragEntry &&
        entry.folder.id != target.id &&
        !_isFolderDescendant(state, entry.folder.id, target.id)) {
      await state.moveFolder(entry.folder, target.id);
    }
  }

  Widget _dropTargetFolder(
    BuildContext context,
    BookmarkFolder folder,
    Widget child,
  ) {
    return DragTarget<_DragEntry>(
      onWillAcceptWithDetails: (details) {
        final entry = details.data;
        final state = context.read<AppState>();
        return entry is _ItemDragEntry ||
            (entry is _FolderDragEntry &&
                entry.folder.id != folder.id &&
                !_isFolderDescendant(state, entry.folder.id, folder.id));
      },
      onAcceptWithDetails: (details) =>
          _dropEntry(context, details.data, folder),
      builder: (context, candidates, rejected) {
        final highlighted = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: highlighted
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            border: highlighted
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: child,
        );
      },
    );
  }

  Widget _draggableEntry({required _DragEntry data, required Widget child}) {
    return LongPressDraggable<_DragEntry>(
      data: data,
      delay: const Duration(milliseconds: 180),
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(14),
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Opacity(opacity: 0.9, child: child),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: child),
      child: child,
    );
  }

  Future<void> _handleBack(BuildContext context) async {
    final state = context.read<AppState>();
    if (state.view != BookmarkView.folder || state.selectedFolderId == null) {
      return;
    }
    final current = state.folders
        .where((folder) => folder.id == state.selectedFolderId)
        .firstOrNull;
    if (current?.parentId == null) {
      await state.selectView(BookmarkView.all);
    } else {
      await state.selectView(BookmarkView.folder, current!.parentId);
    }
  }

  void _handlePageBack(BuildContext context) {
    if (_editMode) {
      setState(() {
        _editMode = false;
        _selectedItemIds.clear();
      });
      return;
    }
    _handleBack(context);
  }

  void _toggleItemSelection(String id) {
    setState(() {
      if (_selectedItemIds.contains(id)) {
        _selectedItemIds.remove(id);
      } else {
        _selectedItemIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final scaffold = Scaffold(
          appBar: AppBar(
            title: Text(switch (state.view) {
              BookmarkView.all => '全部收藏',
              BookmarkView.uncategorized => '未分类',
              BookmarkView.folder =>
                state.folders
                        .where((folder) => folder.id == state.selectedFolderId)
                        .firstOrNull
                        ?.name ??
                    '收藏夹',
            }),
            actions: [
              if (widget.appConfig.supportsRandom)
                IconButton(
                  key: const Key('random-bookmark-button'),
                  tooltip: '今天吃什么',
                  onPressed: state.busy || _randomBusy
                      ? null
                      : () => _showRandom(context),
                  icon: _randomBusy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.casino_outlined),
                ),
              if (state.items.isNotEmpty)
                IconButton(
                  tooltip: _editMode ? '完成编辑' : '编辑收藏',
                  onPressed: () => setState(() {
                    _editMode = !_editMode;
                    if (!_editMode) _selectedItemIds.clear();
                  }),
                  icon: Icon(_editMode ? Icons.check : Icons.edit_outlined),
                ),
              IconButton(
                onPressed: state.busy ? null : state.refresh,
                tooltip: '刷新',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          drawer: wide
              ? null
              : const Drawer(
                  child: FolderNavigation(closeAfterSelection: true),
                ),
          body: Stack(
            children: [
              Column(
                children: [
                  if (_editMode && _selectedItemIds.isNotEmpty)
                    MaterialBanner(
                      content: Text('已选择 ${_selectedItemIds.length} 条收藏'),
                      actions: [
                        TextButton(
                          onPressed: () => _moveSelected(context),
                          child: const Text('批量移动'),
                        ),
                        TextButton(
                          onPressed: () => _deleteSelected(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context)
                                .colorScheme
                                .error,
                          ),
                          child: const Text('批量删除'),
                        ),
                        TextButton(
                          onPressed: () => setState(_selectedItemIds.clear),
                          child: const Text('取消选择'),
                        ),
                      ],
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: SearchBar(
                      controller: _search,
                      hintText: '搜索标题、描述或链接',
                      leading: const Icon(Icons.search),
                      trailing: [
                        IconButton(
                          onPressed: () => state.search(_search.text),
                          icon: const Icon(Icons.arrow_forward),
                        ),
                      ],
                      onSubmitted: state.search,
                    ),
                  ),
                  if (state.error != null)
                    MaterialBanner(
                      content: Text(state.error!),
                      actions: [
                        TextButton(
                          onPressed: state.refresh,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  Expanded(
                    child: state.busy && state.items.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : state.items.isEmpty && _childFolders(state).isEmpty
                        ? const Center(child: Text('这里还没有收藏'))
                        : RefreshIndicator(
                            onRefresh: state.refresh,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount:
                                  _childFolders(state).length +
                                  state.items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final childFolders = _childFolders(state);
                                if (index < childFolders.length) {
                                  final folder = childFolders[index];
                                  final card = Card(
                                    child: ListTile(
                                      leading: const Icon(
                                        Icons.folder_outlined,
                                      ),
                                      title: Text(folder.name),
                                      subtitle: const Text('打开子目录，长按可拖动'),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () =>
                                          _openChildFolder(context, folder),
                                    ),
                                  );
                                  return _dropTargetFolder(
                                    context,
                                    folder,
                                    _draggableEntry(
                                      data: _FolderDragEntry(folder),
                                      child: card,
                                    ),
                                  );
                                }
                                final item =
                                    state.items[index - childFolders.length];
                                final card = BookmarkItemCard(
                                  item: item,
                                  selectionValue: _editMode
                                      ? _selectedItemIds.contains(item.id)
                                      : null,
                                  onSelectionChanged: _editMode
                                      ? (value) => setState(() {
                                          if (value == true) {
                                            _selectedItemIds.add(item.id);
                                          } else {
                                            _selectedItemIds.remove(item.id);
                                          }
                                        })
                                      : null,
                                  onTap: _editMode
                                      ? () => _toggleItemSelection(item.id)
                                      : () => _openLink(context, item),
                                  onAction: (action) {
                                    if (action == 'edit') state.openDraft(item);
                                    if (action == 'move') _move(context, item);
                                    if (action == 'delete') {
                                      state.deleteItem(item.id);
                                    }
                                  },
                                );
                                return _draggableEntry(
                                  data: _ItemDragEntry(item),
                                  child: card,
                                );
                              },
                            ),
                          ),
                  ),
                  if (state.totalPages > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: state.page > 1
                              ? () => state.goToPage(state.page - 1)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('${state.page} / ${state.totalPages}'),
                        IconButton(
                          onPressed: state.page < state.totalPages
                              ? () => state.goToPage(state.page + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                ],
              ),
              Positioned(
                left: _actionLeft,
                top: _actionTop,
                right: _actionLeft == null ? 20 : null,
                bottom: _actionTop == null ? 20 : null,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => _actionDragged = false,
                  onPanUpdate: (details) {
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;
                    setState(() {
                      _actionLeft ??= width - 150;
                      _actionTop ??= height - 76;
                      _actionLeft = (_actionLeft! + details.delta.dx).clamp(
                        8,
                        width - 142,
                      );
                      _actionTop = (_actionTop! + details.delta.dy).clamp(
                        8,
                        height - 60,
                      );
                      _actionDragged = true;
                    });
                  },
                  onPanCancel: () => _actionDragged = false,
                  onTapUp: (_) {
                    if (!_actionDragged) state.openDraft();
                    _actionDragged = false;
                  },
                  child: Material(
                    color: Theme.of(context).colorScheme.primary,
                    elevation: 6,
                    borderRadius: BorderRadius.circular(28),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_link,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '收藏链接',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        final content = wide
            ? Row(
                children: [
                  const SizedBox(
                    width: 300,
                    child: Material(child: FolderNavigation()),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: scaffold),
                ],
              )
            : scaffold;
        return PopScope(
          canPop: !_editMode && state.view != BookmarkView.folder,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _handlePageBack(context);
          },
          child: content,
        );
      },
    );
  }
}
