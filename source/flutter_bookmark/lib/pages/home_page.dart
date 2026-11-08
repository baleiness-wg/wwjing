import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/bookmark_item_card.dart';
import '../components/ai_chat_sheet.dart';
import '../components/folder_picker_dialog.dart';
import '../components/random_folders_filter_dialog.dart';
import '../constants/app_config.dart';
import '../stores/bookmark_state.dart';
import '../viewmodels/bookmark.dart';
import '../utils/link_launcher.dart';
import 'folder_navigation.dart';

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
  bool _editMode = false;
  bool _randomBusy = false;
  final Set<String> _selectedItemIds = {};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _move(BuildContext context, BookmarkItem item) async {
    final state = context.read<AppState>();
    final folderId = await showFolderPicker(
      context: context,
      state: state,
      title: '移动到',
      selectedFolderId: item.folderId,
      rootLabel: '未分类',
    );
    if (folderId != null && context.mounted) {
      await state.moveItem(item.id, folderId.isEmpty ? null : folderId);
    }
  }

  Future<void> _moveSelected(BuildContext context) async {
    final state = context.read<AppState>();
    final folderId = await showFolderPicker(
      context: context,
      state: state,
      title: '批量移动到',
      rootLabel: '未分类',
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

  String _folderPath(AppState state, String? folderId) {
    if (folderId == null) return '未分类';
    final byId = {for (final folder in state.folders) folder.id: folder};
    final names = <String>[];
    final visited = <String>{};
    var current = byId[folderId];
    while (current != null && visited.add(current.id)) {
      names.insert(0, current.name);
      current = current.parentId == null ? null : byId[current.parentId];
    }
    return names.isEmpty ? '未知目录' : names.join(' / ');
  }

  Future<void> _showAiChat(BuildContext context, AppState state) {
    final directoryId = state.view == BookmarkView.folder
        ? state.selectedFolderId
        : null;
    final directoryName = switch (state.view) {
      BookmarkView.all => '全部收藏',
      BookmarkView.uncategorized => '未分类',
      BookmarkView.folder =>
        state.folders
                .where((folder) => folder.id == state.selectedFolderId)
                .firstOrNull
                ?.name ??
            '收藏夹',
    };
    final directoryPath = state.view == BookmarkView.folder
        ? _folderPath(state, state.selectedFolderId)
        : directoryName;
    final directoryContext = <String, Object?>{
      'space': widget.appConfig.space,
      'directoryId': directoryId,
      'directoryName': directoryName,
      'directoryPath': directoryPath,
      'loadedItemCount': state.items.length,
      'items': [
        for (final item in state.items)
          {
            'title': item.title,
            'description': item.description,
            'sourceHost': item.sourceHost,
            'sourceUrl': item.sourceUrl,
            'folderPath': _folderPath(state, item.folderId),
          },
      ],
    };
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => AiChatSheet(
        api: state.api,
        directoryContext: directoryContext,
        linkLauncher: widget.linkLauncher,
      ),
    );
  }

  Future<void> _showRandom(BuildContext context) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // 1. 先弹出目录多选范围确认窗口（若在特定文件夹内则默认仅预选该文件夹，在全部收藏则默认全选）
    final selected = await showRandomFoldersFilterDialog(
      context: context,
      state: state,
      currentFolderId: state.selectedFolderId,
    );
    if (!mounted || selected == null) return;

    await state.updateSelectedRandomFolderIds(
      selected.isEmpty ? null : selected,
    );

    // 2. 展开选中文件夹的所有子目录，随机选一个传给 API（与 web 端行为一致）
    final candidateIds = <String>[];
    for (final id
        in selected.isEmpty ? state.folders.map((f) => f.id) : selected) {
      _collectDescendantIds(state.folders, id, candidateIds);
    }
    if (candidateIds.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('选中的目录中没有可推荐内容')));
      return;
    }
    final targetFolderId =
        candidateIds[DateTime.now().millisecondsSinceEpoch %
            candidateIds.length];

    if (_randomBusy) return;
    setState(() => _randomBusy = true);
    final item = await state.randomItem(folderIds: [targetFolderId]);
    if (!mounted) return;
    setState(() => _randomBusy = false);
    if (item == null) {
      final message = state.error ?? '选中的目录中暂无可推荐内容';
      messenger.showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    // 3. 弹出低高度抽卡结果弹窗，支持“换一个”实时轮换
    await showDialog<void>(
      context: navigator.context,
      builder: (dialogContext) {
        var currentItem = item;
        return StatefulBuilder(
          builder: (innerContext, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Expanded(child: Text('Today')),
                  IconButton(
                    key: const Key('random-again-button'),
                    tooltip: '换一个',
                    icon: const Icon(Icons.refresh),
                    onPressed: () async {
                      final nextItem = await state.randomItem(
                        folderIds: [targetFolderId],
                      );
                      if (nextItem != null && innerContext.mounted) {
                        setDialogState(() {
                          currentItem = nextItem;
                        });
                      }
                    },
                  ),
                ],
              ),
              content: ConstrainedBox(
                key: const Key('random-bookmark-content'),
                constraints: const BoxConstraints(
                  maxWidth: 520,
                  maxHeight: 150,
                ),
                child: BookmarkItemCard(
                  item: currentItem,
                  onTap: () => _openLink(innerContext, currentItem),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _collectDescendantIds(
    List<BookmarkFolder> folders,
    String parentId,
    List<String> result,
  ) {
    result.add(parentId);
    for (final folder in folders) {
      if (folder.parentId == parentId) {
        _collectDescendantIds(folders, folder.id, result);
      }
    }
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

  void _exitEditMode() {
    setState(() {
      _editMode = false;
      _selectedItemIds.clear();
    });
  }

  void _toggleSelectAll(AppState state) {
    final ids = state.items.map((item) => item.id).toSet();
    setState(() {
      if (_selectedItemIds.length == ids.length && ids.isNotEmpty) {
        _selectedItemIds.clear();
      } else {
        _selectedItemIds
          ..clear()
          ..addAll(ids);
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
            leadingWidth: _editMode ? 72 : null,
            leading: _editMode
                ? TextButton(
                    key: const Key('cancel-selection-button'),
                    onPressed: _exitEditMode,
                    child: const Text('取消'),
                  )
                : null,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(switch (state.view) {
                  BookmarkView.all => '全部收藏',
                  BookmarkView.uncategorized => '未分类',
                  BookmarkView.folder =>
                    state.folders
                            .where(
                              (folder) => folder.id == state.selectedFolderId,
                            )
                            .firstOrNull
                            ?.name ??
                        '收藏夹',
                }),
                if (!_editMode) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    key: const Key('random-bookmark-button'),
                    tooltip: 'Today',
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
                ],
              ],
            ),
            actions: [
              if (_editMode)
                TextButton(
                  key: const Key('select-all-button'),
                  onPressed: () => _toggleSelectAll(state),
                  child: Text(
                    _selectedItemIds.length == state.items.length &&
                            state.items.isNotEmpty
                        ? '取消全选'
                        : '全选',
                  ),
                ),
              if (_editMode)
                TextButton(
                  key: const Key('save-selection-button'),
                  onPressed: _exitEditMode,
                  child: const Text('保存'),
                ),
              if (!_editMode)
                IconButton(
                  key: const Key('add-bookmark-button'),
                  tooltip: '收藏链接',
                  onPressed: () {
                    if (state.selectedFolderId != null) {
                      state.openDraftInFolder(state.selectedFolderId!);
                    } else {
                      state.openDraft();
                    }
                  },
                  icon: const Icon(Icons.add),
                ),
              if (!_editMode && state.items.isNotEmpty)
                IconButton(
                  tooltip: '编辑收藏',
                  onPressed: () => setState(() {
                    _editMode = true;
                  }),
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
          drawer: wide
              ? null
              : Drawer(
                  child: FolderNavigation(
                    closeAfterSelection: true,
                    appConfig: widget.appConfig,
                  ),
                ),
          body: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
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
                        : state.items.isEmpty
                        ? const Center(child: Text('这里还没有收藏'))
                        : RefreshIndicator(
                            onRefresh: state.refresh,
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (notification) {
                                if (notification.metrics.extentAfter < 500) {
                                  state.loadMore();
                                }
                                return false;
                              },
                              child: ListView.separated(
                                padding: EdgeInsets.fromLTRB(
                                  6,
                                  6,
                                  6,
                                  _editMode ? 92 : 12,
                                ),
                                itemCount:
                                    state.items.length +
                                    (state.loadingMore ? 1 : 0),
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 4),
                                itemBuilder: (context, index) {
                                  if (index == state.items.length) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  final item = state.items[index];
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
                                      if (action == 'edit') {
                                        state.openDraft(item);
                                      }
                                      if (action == 'move') {
                                        _move(context, item);
                                      }
                                      if (action == 'delete') {
                                        state.deleteItem(item.id);
                                      }
                                    },
                                  );
                                  return card;
                                },
                              ),
                            ),
                          ),
                  ),
                ],
              ),
              if (_editMode)
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: SafeArea(
                    top: false,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.tonalIcon(
                          key: const Key('move-selection-button'),
                          onPressed: _selectedItemIds.isEmpty
                              ? null
                              : () => _moveSelected(context),
                          icon: const Icon(Icons.drive_file_move_outline),
                          label: const Text('移动'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          key: const Key('delete-selection-button'),
                          onPressed: _selectedItemIds.isEmpty
                              ? null
                              : () => _deleteSelected(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .error,
                            foregroundColor: Theme.of(context)
                                .colorScheme
                                .onError,
                          ),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('删除'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!_editMode)
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: SafeArea(
                    top: false,
                    child: FloatingActionButton(
                      key: const Key('ai-chat-button'),
                      tooltip: '和 AI 讨论当前目录',
                      onPressed: state.busy
                          ? null
                          : () => _showAiChat(context, state),
                      child: const Icon(Icons.auto_awesome),
                    ),
                  ),
                ),
            ],
          ),
        );
        final content = wide
            ? Row(
                children: [
                  SizedBox(
                    width: 300,
                    child: Material(
                      child: FolderNavigation(appConfig: widget.appConfig),
                    ),
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
