import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../components/folder_picker_dialog.dart';
import '../components/bookmark_cover.dart';
import '../stores/bookmark_state.dart';
import '../viewmodels/bookmark.dart';
import '../utils/link_launcher.dart';
import '../utils/shared_link_parser.dart';
import '../utils/bilibili_resolver.dart';
import '../utils/douyin_resolver.dart';

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
  late final TextEditingController _imageUrl;
  String? _folderId;
  List<String> _images = const [];
  bool _recognizing = false;
  Future<BookmarkMetadata?>? _metadataFuture;
  BookmarkDraft? _lastObservedDraft;

  @override
  void initState() {
    super.initState();
    final draft = context.read<AppState>().draft!;
    _lastObservedDraft = draft;
    _url = TextEditingController(text: draft.sourceUrl);
    _title = TextEditingController(text: draft.title);
    _description = TextEditingController(text: draft.description);
    _imageUrl = TextEditingController(text: draft.images.isEmpty ? '' : draft.images.first);
    _folderId = draft.folderId;
    _images = draft.images;
    if (draft.fetchMetadataOnOpen && draft.sourceUrl.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _metadataFuture = _recognizeCover();
      });
    }
  }

  void _applyDraft(BookmarkDraft draft) {
    setState(() {
      _lastObservedDraft = draft;
      _url.text = draft.sourceUrl;
      _title.text = draft.title;
      _description.text = draft.description;
      _imageUrl.text = draft.images.isEmpty ? '' : draft.images.first;
      _folderId = draft.folderId;
      _images = draft.images;
    });
    if (draft.fetchMetadataOnOpen && draft.sourceUrl.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _metadataFuture = _recognizeCover();
      });
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _title.dispose();
    _description.dispose();
    _imageUrl.dispose();
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
    _metadataFuture = _recognizeCover();
  }

  void _onUrlChanged(String value) {
    setState(() {});
  }

  Future<BookmarkMetadata?> _recognizeCover() async {
    final url = _url.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先输入链接')));
      return null;
    }
    setState(() => _recognizing = true);
    final state = context.read<AppState>();
    BookmarkMetadata? metadata;
    final requestUrl = url;
    if (DouyinResolver.isDouyinUrl(url)) {
      final value = await DouyinResolver().resolve(url);
      if (value != null) {
        metadata = BookmarkMetadata(
          finalUrl: value.finalUrl,
          title: value.title,
          description: value.description,
          coverUrl: value.coverUrl,
        );
      }
    }
    if (metadata == null && BilibiliResolver.isBilibiliUrl(requestUrl)) {
      final value = await BilibiliResolver().resolve(requestUrl);
      if (value != null) {
        metadata = BookmarkMetadata(
          finalUrl: value.finalUrl,
          title: value.title,
          description: value.description,
          coverUrl: value.coverUrl,
        );
      }
    }
    metadata ??= await state.fetchBookmarkMetadata(requestUrl);
    if (!mounted) return metadata;
    setState(() {
      _recognizing = false;
      if (metadata?.coverUrl?.trim().isNotEmpty == true) {
        _imageUrl.text = metadata!.coverUrl!.trim();
        _images = [_imageUrl.text, ..._images.where((value) => value != _imageUrl.text)];
      }
      if (_title.text.trim().isEmpty && metadata?.title?.trim().isNotEmpty == true) {
        _title.text = metadata!.title!.trim();
      }
      if (_description.text.trim().isEmpty && metadata?.description?.trim().isNotEmpty == true) {
        _description.text = metadata!.description!.trim();
      }
    });
    return metadata;
  }

  Future<void> _save({bool allowDuplicate = false}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入标题')));
      return;
    }
    final state = context.read<AppState>();
    final sourceUrl = _url.text.trim();
    final value = BookmarkDraft(
      sourceUrl: sourceUrl,
      title: _title.text.trim(),
      description: _description.text.trim(),
      folderId: _folderId,
      images: _imageUrl.text.trim().isEmpty ? const [] : [_imageUrl.text.trim()],
    );
    final saved = await state.saveDraft(
      value,
      allowDuplicate: allowDuplicate,
      metadataFuture: _metadataFuture,
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
              TextFormField(
                controller: _url,
                autofocus: _url.text.isEmpty,
                decoration: InputDecoration(
                  labelText: '链接（可选）',
                  prefixIcon: const Icon(Icons.link),
                  suffixIcon: IconButton(
                    onPressed: () => openExternalLink(context, _url.text),
                    tooltip: '打开链接',
                    icon: const Icon(Icons.open_in_new),
                  ),
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
              const SizedBox(height: 14),
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: '标题（必填）'),
                onChanged: (_) => setState(() {}),
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
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BookmarkCover(
                    sourceUrl: _url.text,
                    coverUrl: _imageUrl.text,
                    width: 88,
                    height: 88,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _imageUrl,
                      decoration: const InputDecoration(
                        labelText: '图片 URL（可选）',
                        prefixIcon: Icon(Icons.image_outlined),
                      ),
                      keyboardType: TextInputType.url,
                      onChanged: (value) => setState(() {
                        _images = value.trim().isEmpty ? const [] : [value.trim()];
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _recognizing
                      ? null
                      : () => _metadataFuture = _recognizeCover(),
                  icon: _recognizing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_outlined),
                  label: Text(_images.isEmpty ? '识别封面' : '重新识别封面'),
                ),
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
