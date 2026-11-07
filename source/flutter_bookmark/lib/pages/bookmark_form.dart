import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../components/folder_picker_dialog.dart';
import '../stores/bookmark_state.dart';
import '../viewmodels/bookmark.dart';
import '../utils/link_launcher.dart';
import '../utils/shared_link_parser.dart';

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
  BookmarkDraft? _lastObservedDraft;

  @override
  void initState() {
    super.initState();
    final draft = context.read<AppState>().draft!;
    _lastObservedDraft = draft;
    _url = TextEditingController(text: draft.sourceUrl);
    _title = TextEditingController(text: draft.title);
    _description = TextEditingController(text: draft.description);
    _folderId = draft.folderId;
  }

  void _applyDraft(BookmarkDraft draft) {
    setState(() {
      _lastObservedDraft = draft;
      _url.text = draft.sourceUrl;
      _title.text = draft.title;
      _description.text = draft.description;
      _folderId = draft.folderId;
    });
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
      // 粘贴时若有分享导言可作为兜底，但仍优先允许元数据填入网页真实标题
      if (_title.text.isEmpty && shared.title.isNotEmpty) {
        _title.text = shared.title;
      }
      if (_description.text.isEmpty && shared.originalText.isNotEmpty) {
        _description.text = shared.originalText;
      }
    });
    // 粘贴只填充链接和分享文本，不再自动识别网页封面。
  }

  void _onUrlChanged(String value) {
    setState(() {});
  }

  Future<void> _save({bool allowDuplicate = false}) async {
    if (!_formKey.currentState!.validate()) return;
    final state = context.read<AppState>();
    final sourceUrl = _url.text.trim();
    final value = BookmarkDraft(
      sourceUrl: sourceUrl,
      title: _title.text.trim(),
      description: _description.text.trim(),
      folderId: _folderId,
    );
    final saved = await state.saveDraft(
      value,
      allowDuplicate: allowDuplicate,
    );
    if (!mounted) return;
    if (saved) return;
    if (state.errorCode == 'DUPLICATE_BOOKMARK') {
      final duplicate = DuplicateBookmarkInfo.fromJson(state.errorData);
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('链接已收藏'),
          content: Text(
            '已有收藏：${duplicate.title?.isNotEmpty == true ? duplicate.title : _url.text.trim()}\n所在位置：${duplicate.folderName ?? '未分类'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'open'),
              child: const Text('打开原链接'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'folder'),
              child: const Text('查看文件夹'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'overwrite'),
              child: const Text('覆盖原收藏'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'duplicate'),
              child: const Text('另存一份'),
            ),
          ],
        ),
      );
      if (!mounted || action == null) return;
      if (action == 'open') {
        await openExternalLink(context, value.sourceUrl);
      } else if (action == 'folder') {
        await state.openFolder(duplicate.folderId);
        if (mounted) state.closeDraft();
      } else if (action == 'overwrite' && duplicate.id.isNotEmpty) {
        final overwritten = await state.overwriteItem(duplicate.id, value);
        if (overwritten && mounted) state.closeDraft();
      } else if (action == 'duplicate') {
        await state.saveDraft(
          value,
          allowDuplicate: true,
        );
      }
    }
  }

  Future<void> _chooseFolder(List<FolderNode> nodes) async {
    final state = context.read<AppState>();
    final selected = await showFolderPicker(
      context: context,
      state: state,
      title: '选择收藏夹',
      selectedFolderId: _folderId,
      rootLabel: '未分类',
      allowCreate: true,
    );
    if (!mounted || selected == null) return;
    setState(() => _folderId = selected.isEmpty ? null : selected);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.draft != null && state.draft != _lastObservedDraft) {
      final newDraft = state.draft!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyDraft(newDraft);
      });
    }
    final folderNodes = flattenFolderTree(state.folderTree).toList();

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
                minLines: 8,
                maxLines: 16,
              ),
              const SizedBox(height: 14),
              ExpansionTile(
                title: const Text('高级设置'),
                subtitle: const Text('链接用于保存和去重，默认不显示'),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                children: [
                  TextFormField(
                    controller: _url,
                    autofocus: _url.text.isEmpty,
                    decoration: const InputDecoration(
                      labelText: '链接（可选）',
                      prefixIcon: Icon(Icons.link),
                    ),
                    keyboardType: TextInputType.url,
                    onChanged: _onUrlChanged,
                    validator: (value) {
                      final uri = Uri.tryParse(value?.trim() ?? '');
                      return value == null || value.trim().isEmpty ||
                              (uri != null && uri.hasAuthority &&
                                  (uri.scheme == 'http' || uri.scheme == 'https'))
                          ? null
                          : '请输入有效的 HTTP/HTTPS 链接';
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Card.outlined(
                key: const Key('folder-picker-trigger'),
                child: ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: const Text('收藏夹'),
                  subtitle: Text(
                    _folderId == null
                        ? '未分类'
                        : folderNodes
                              .firstWhere((node) => node.folder.id == _folderId)
                              .folder
                              .name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _chooseFolder(folderNodes),
                ),
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
