import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_config.dart';
import '../stores/bookmark_state.dart';
import '../viewmodels/bookmark.dart';

class InspirationLibraryPage extends StatefulWidget {
  const InspirationLibraryPage({super.key, required this.appConfig});

  final AppConfig appConfig;

  @override
  State<InspirationLibraryPage> createState() => _InspirationLibraryPageState();
}

class _InspirationLibraryPageState extends State<InspirationLibraryPage> {
  List<InspirationEntry> _entries = [];
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await context.read<AppState>().api.getInspirations();
      if (mounted) {
        setState(() {
          _entries = entries;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([InspirationEntry? entry]) async {
    final state = context.read<AppState>();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InspirationEditorSheet(
        entry: entry,
        folders: state.folders,
        onSave: (title, content, folderId) async {
          if (entry == null) {
            await state.api.createInspiration(
              content: content,
              title: title,
              folderId: folderId,
            );
          } else {
            await state.api.updateInspiration(
              entry.id,
              content: content,
              title: title,
              folderId: folderId,
            );
          }
        },
      ),
    );
    if (result == true) _load();
  }

  Future<void> _delete(InspirationEntry entry) async {
    final api = context.read<AppState>().api;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除灵感'),
        content: const Text('确定删除这条灵感吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await api.deleteInspiration(entry.id);
      if (mounted) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('灵感库')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: const Text('记录'),
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
          ? const Center(child: Text('还没有灵感，想到什么就记下来吧'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: _entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = _entries[index];
                final folder = state.folders
                    .where((item) => item.id == entry.folderId)
                    .firstOrNull;
                return Card(
                  child: InkWell(
                    onTap: () => _edit(entry),
                    onLongPress: () => _delete(entry),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title?.isNotEmpty == true
                                ? entry.title!
                                : '未命名灵感',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            entry.content,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (folder != null) ...[
                            const SizedBox(height: 10),
                            Chip(
                              avatar: const Icon(
                                Icons.folder_outlined,
                                size: 16,
                              ),
                              label: Text(folder.name),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _InspirationEditorSheet extends StatefulWidget {
  const _InspirationEditorSheet({
    required this.entry,
    required this.folders,
    required this.onSave,
  });

  final InspirationEntry? entry;
  final List<BookmarkFolder> folders;
  final Future<void> Function(String title, String content, String? folderId)
  onSave;

  @override
  State<_InspirationEditorSheet> createState() =>
      _InspirationEditorSheetState();
}

class _InspirationEditorSheetState extends State<_InspirationEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  String? _folderId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.entry?.title ?? '');
    _content = TextEditingController(text: widget.entry?.content ?? '');
    _folderId = widget.entry?.folderId;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_content.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_title.text, _content.text, _folderId);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      16,
      20,
      16,
      MediaQuery.viewInsetsOf(context).bottom + 16,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.entry == null ? '记录灵感' : '编辑灵感',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: '标题（可选）'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _content,
          maxLines: 6,
          autofocus: widget.entry == null,
          decoration: const InputDecoration(
            labelText: '想到什么就写什么',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: _folderId,
          decoration: const InputDecoration(labelText: '关联收藏夹目录（可选）'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('不关联目录')),
            ...widget.folders.map(
              (folder) => DropdownMenuItem<String?>(
                value: folder.id,
                child: Text(folder.name),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _folderId = value),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '保存中...' : '保存'),
        ),
      ],
    ),
  );
}
