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

  Future<void> _openLink(BuildContext context, BookmarkItem item) async {
    await openExternalLink(context, item.sourceUrl);
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
          body: Column(
            children: [
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
                    : state.items.isEmpty
                    ? const Center(child: Text('这里还没有收藏'))
                    : RefreshIndicator(
                        onRefresh: state.refresh,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: state.items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = state.items[index];
                            return Card(
                              child: ListTile(
                                leading: BookmarkCover(
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
                                onTap: () => state.openDraft(item),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () => _openLink(context, item),
                                      tooltip: '打开链接',
                                      icon: const Icon(Icons.open_in_new),
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (action) {
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
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text('编辑'),
                                        ),
                                        PopupMenuItem(
                                          value: 'move',
                                          child: Text('移动'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('删除'),
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
          floatingActionButton: FloatingActionButton.extended(
            onPressed: state.openDraft,
            icon: const Icon(Icons.add_link),
            label: const Text('收藏链接'),
          ),
        );
        return wide
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
      },
    );
  }
}
