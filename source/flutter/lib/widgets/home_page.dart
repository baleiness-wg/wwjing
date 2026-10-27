import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bookmark.dart';
import '../services/link_launcher.dart';
import '../state/app_state.dart';
import 'bookmark_cover.dart';
import 'folder_navigation.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _search = TextEditingController();
  double? _actionLeft;
  double? _actionTop;
  bool _actionDragged = false;
  bool _editMode = false;
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
          SimpleDialogOption(onPressed: () => Navigator.pop(context, ''), child: const Text('未分类')),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
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
    await openExternalLink(context, item.sourceUrl);
  }

  Future<void> _openChildFolder(BuildContext context, BookmarkFolder folder) async {
    await context.read<AppState>().selectView(BookmarkView.folder, folder.id);
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
                        TextButton(onPressed: () => _moveSelected(context), child: const Text('批量移动')),
                        TextButton(
                          onPressed: () => _deleteSelected(context),
                          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                          child: const Text('批量删除'),
                        ),
                        TextButton(onPressed: () => setState(_selectedItemIds.clear), child: const Text('取消选择')),
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
                              itemCount: _childFolders(state).length + state.items.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final childFolders = _childFolders(state);
                                if (index < childFolders.length) {
                                  final folder = childFolders[index];
                                  return Card(
                                    child: ListTile(
                                      leading: const Icon(Icons.folder_outlined),
                                      title: Text(folder.name),
                                      subtitle: const Text('打开子目录'),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => _openChildFolder(context, folder),
                                    ),
                                  );
                                }
                                final item = state.items[index - childFolders.length];
                                return Card(
                                  child: ListTile(
                                    leading: _editMode
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Checkbox(
                                                value: _selectedItemIds.contains(item.id),
                                                onChanged: (value) => setState(() {
                                                  if (value == true) {
                                                    _selectedItemIds.add(item.id);
                                                  } else {
                                                    _selectedItemIds.remove(item.id);
                                                  }
                                                }),
                                              ),
                                              BookmarkCover(
                                                sourceUrl: item.sourceUrl,
                                                sourceHost: item.sourceHost,
                                                coverUrl: item.coverUrl,
                                                width: 58,
                                                height: 58,
                                              ),
                                            ],
                                          )
                                        : BookmarkCover(
                                            sourceUrl: item.sourceUrl,
                                            sourceHost: item.sourceHost,
                                            coverUrl: item.coverUrl,
                                            width: 58,
                                            height: 58,
                                          ),
                                    title: Text(
                                      item.title?.isNotEmpty == true
                                          ? item.title!
                                          : item.sourceUrl,
                                    ),
                                    subtitle: Text(
                                      item.sourceHost ?? item.sourceUrl,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: _editMode
                                        ? () => _toggleItemSelection(item.id)
                                        : () => _openLink(context, item),
                                    trailing: PopupMenuButton<String>(
                                      tooltip: '更多操作',
                                      onSelected: (action) {
                                        if (action == 'edit') state.openDraft(item);
                                        if (action == 'move') _move(context, item);
                                        if (action == 'delete') state.deleteItem(item.id);
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(value: 'edit', child: Text('编辑')),
                                        PopupMenuItem(value: 'move', child: Text('移动')),
                                        PopupMenuItem(value: 'delete', child: Text('删除')),
                                      ],
                                    ),
                                  ),
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
                          onPressed: state.page > 1 ? () => state.goToPage(state.page - 1) : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('${state.page} / ${state.totalPages}'),
                        IconButton(
                          onPressed: state.page < state.totalPages ? () => state.goToPage(state.page + 1) : null,
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
                      _actionLeft = (_actionLeft! + details.delta.dx).clamp(8, width - 142);
                      _actionTop = (_actionTop! + details.delta.dy).clamp(8, height - 60);
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_link, color: Theme.of(context).colorScheme.onPrimary),
                          const SizedBox(width: 8),
                          Text(
                            '收藏链接',
                            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
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
