import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/bookmark.dart';
import '../models/shared_link.dart';
import '../state/app_state.dart';

class BookmarkForm extends StatefulWidget {
  const BookmarkForm({super.key});

  @override
  State<BookmarkForm> createState() => _BookmarkFormState();
}

class _BookmarkFormState extends State<BookmarkForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _url;
  late final TextEditingController _title;
  late final TextEditingController _description;
  String? _folderId;

  @override
  void initState() {
    super.initState();
    final draft = context.read<AppState>().draft!;
    _url = TextEditingController(text: draft.sourceUrl);
    _title = TextEditingController(text: draft.title);
    _description = TextEditingController(text: draft.description);
    _folderId = draft.folderId;
  }

  @override
  void dispose() {
    _url.dispose();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    final shared = extractSharedLink(text);
    if (!mounted) return;
    if (shared == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('剪贴板中没有有效链接')));
      return;
    }
    setState(() {
      _url.text = shared.url;
      if (_title.text.isEmpty) _title.text = shared.title;
      if (_description.text.isEmpty) _description.text = shared.originalText;
    });
  }

  Future<void> _save({bool allowDuplicate = false}) async {
    if (!_formKey.currentState!.validate()) return;
    final state = context.read<AppState>();
    final value = BookmarkDraft(
      sourceUrl: _url.text.trim(),
      title: _title.text.trim(),
      description: _description.text.trim(),
      folderId: _folderId,
    );
    final saved = await state.saveDraft(value, allowDuplicate: allowDuplicate);
    if (!mounted || saved) return;
    if (state.errorCode == 'DUPLICATE_BOOKMARK') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('链接已收藏'),
          content: const Text('仍要再保存一份吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('继续保存'),
            ),
          ],
        ),
      );
      if (confirm == true) await state.saveDraft(value, allowDuplicate: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final recent = state.recentFolderIds
        .map(
          (id) => state.folders.where((folder) => folder.id == id).firstOrNull,
        )
        .whereType<BookmarkFolder>()
        .toList();
    final treeFolders = flattenFolderTree(state.folderTree)
        .map((node) => node.folder)
        .toList();
    final ordered = [
      ...recent,
      ...treeFolders.where(
        (folder) => !recent.any((item) => item.id == folder.id),
      ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) state.closeDraft();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(state.editingItemId == null ? '快速收藏' : '编辑收藏'),
          actions: [
            TextButton.icon(
              onPressed: _paste,
              icon: const Icon(Icons.content_paste),
              label: const Text('粘贴'),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _url,
                autofocus: _url.text.isEmpty,
                decoration: const InputDecoration(
                  labelText: '链接',
                  prefixIcon: Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
                validator: (value) {
                  final uri = Uri.tryParse(value?.trim() ?? '');
                  return uri != null &&
                          uri.hasAuthority &&
                          (uri.scheme == 'http' || uri.scheme == 'https')
                      ? null
                      : '请输入 HTTP/HTTPS 链接';
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: '标题（可选）'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _description,
                decoration: const InputDecoration(
                  labelText: '描述（可选）',
                  alignLabelWithHint: true,
                ),
                minLines: 3,
                maxLines: 6,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                initialValue: _folderId,
                decoration: const InputDecoration(labelText: '收藏夹'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('未分类')),
                  for (final folder in ordered)
                    DropdownMenuItem(
                      value: folder.id,
                      child: Text(folder.name),
                    ),
                ],
                onChanged: (value) => setState(() => _folderId = value),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: state.busy ? null : _save,
                icon: state.busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bookmark_add),
                label: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('保存'),
                ),
              ),
              if (state.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
