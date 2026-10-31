import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/bookmark.dart';
import '../models/shared_link.dart';
import '../services/bilibili_resolver.dart';
import '../services/douyin_resolver.dart';
import '../services/link_launcher.dart';
import '../state/app_state.dart';
import 'bookmark_cover.dart';
import 'folder_picker_dialog.dart';

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
  late final TextEditingController _coverUrl;
  String? _folderId;
  bool _recognizing = false;
  BookmarkDraft? _lastObservedDraft;

  @override
  void initState() {
    super.initState();
    final draft = context.read<AppState>().draft!;
    _lastObservedDraft = draft;
    _url = TextEditingController(text: draft.sourceUrl);
    _title = TextEditingController(text: draft.title);
    _description = TextEditingController(text: draft.description);
    _coverUrl = TextEditingController(text: draft.coverUrl);
    _folderId = draft.folderId;
    if (draft.fetchMetadataOnOpen && draft.sourceUrl.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _recognizeMetadata());
    }
  }

  void _applyDraft(BookmarkDraft draft) {
    setState(() {
      _lastObservedDraft = draft;
      _url.text = draft.sourceUrl;
      _title.text = draft.title;
      _description.text = draft.description;
      _coverUrl.text = draft.coverUrl;
      _folderId = draft.folderId;
    });
    if (draft.fetchMetadataOnOpen && draft.sourceUrl.isNotEmpty) {
      _recognizeMetadata(overrideTitle: true);
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _title.dispose();
    _description.dispose();
    _coverUrl.dispose();
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
    // 粘贴有效链接后自动异步识别封面与完整信息
    await _recognizeMetadata(overrideTitle: true);
  }

  Future<void> _recognizeMetadata({bool overrideTitle = false}) async {
    final uri = Uri.tryParse(_url.text.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先输入有效的 HTTP/HTTPS 链接')));
      return;
    }
    setState(() => _recognizing = true);
    final state = context.read<AppState>();

    // 抖音短链或视频优先尝试客户端专用解析
    if (DouyinResolver.isDouyinUrl(uri.toString())) {
      final dyMetadata = await DouyinResolver().resolve(uri.toString());
      if (dyMetadata != null && mounted) {
        setState(() {
          _recognizing = false;
          if ((overrideTitle || _title.text.trim().isEmpty) &&
              dyMetadata.title?.trim().isNotEmpty == true) {
            _title.text = dyMetadata.title!.trim();
          }
          if (_description.text.trim().isEmpty &&
              dyMetadata.description?.trim().isNotEmpty == true) {
            _description.text = dyMetadata.description!.trim();
          }
          if (_coverUrl.text.trim().isEmpty &&
              dyMetadata.coverUrl?.trim().isNotEmpty == true) {
            _coverUrl.text = dyMetadata.coverUrl!.trim();
          }
          if (_title.text.trim().isEmpty) {
            _title.text = titleFallbackForUrl(uri);
          }
        });
        return;
      }
    }

    // 哔哩哔哩链接优先尝试客户端直连官方开放接口
    if (BilibiliResolver.isBilibiliUrl(uri.toString())) {
      final biliMetadata = await BilibiliResolver().resolve(uri.toString());
      if (biliMetadata != null && mounted) {
        setState(() {
          _recognizing = false;
          if ((overrideTitle || _title.text.trim().isEmpty) &&
              biliMetadata.title?.trim().isNotEmpty == true) {
            _title.text = biliMetadata.title!.trim();
          }
          if (_description.text.trim().isEmpty &&
              biliMetadata.description?.trim().isNotEmpty == true) {
            _description.text = biliMetadata.description!.trim();
          }
          if (_coverUrl.text.trim().isEmpty &&
              biliMetadata.coverUrl?.trim().isNotEmpty == true) {
            _coverUrl.text = biliMetadata.coverUrl!.trim();
          }
          if (biliMetadata.finalUrl.trim().isNotEmpty) {
            _url.text = biliMetadata.finalUrl.trim();
          }
          if (_title.text.trim().isEmpty) {
            _title.text = titleFallbackForUrl(uri);
          }
        });
        return;
      }
    }

    final metadata = await state.fetchBookmarkMetadata(uri.toString());
    if (!mounted) return;
    setState(() {
      _recognizing = false;
      if (metadata != null) {
        if ((overrideTitle || _title.text.trim().isEmpty) &&
            metadata.title?.trim().isNotEmpty == true) {
          _title.text = metadata.title!.trim();
        }
        if (_description.text.trim().isEmpty &&
            metadata.description?.trim().isNotEmpty == true) {
          _description.text = metadata.description!.trim();
        }
        if (_coverUrl.text.trim().isEmpty &&
            metadata.coverUrl?.trim().isNotEmpty == true) {
          _coverUrl.text = metadata.coverUrl!.trim();
        }
        if (metadata.finalUrl?.trim().isNotEmpty == true) {
          _url.text = metadata.finalUrl!.trim();
        }
      }
      if (_title.text.trim().isEmpty) {
        _title.text = titleFallbackForUrl(uri);
      }
    });
    if (metadata == null && state.metadataMessage != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(state.metadataMessage!)));
    }
  }

  Future<void> _save({bool allowDuplicate = false}) async {
    if (!_formKey.currentState!.validate()) return;
    final state = context.read<AppState>();
    var sourceUrl = _url.text.trim();
    final uri = Uri.parse(sourceUrl);
    if (isXiaohongshuShortLink(uri)) {
      setState(() => _recognizing = true);
      final metadata = await state.fetchBookmarkMetadata(sourceUrl);
      if (!mounted) return;
      setState(() => _recognizing = false);
      final finalUrl = metadata?.finalUrl?.trim();
      final finalUri = finalUrl == null ? null : Uri.tryParse(finalUrl);
      if (finalUri == null || !isCompleteXiaohongshuUrl(finalUri)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('小红书短链解析失败，请稍后重试')));
        return;
      }
      sourceUrl = finalUrl!;
      _url.text = sourceUrl;
      if (_coverUrl.text.trim().isEmpty &&
          metadata?.coverUrl?.trim().isNotEmpty == true) {
        _coverUrl.text = metadata!.coverUrl!.trim();
      }
      if (_title.text.trim().isEmpty &&
          metadata?.title?.trim().isNotEmpty == true) {
        _title.text = metadata!.title!.trim();
      }
    }
    final value = BookmarkDraft(
      sourceUrl: sourceUrl,
      title: _title.text.trim(),
      description: _description.text.trim(),
      folderId: _folderId,
      coverUrl: _coverUrl.text.trim(),
    );
    final saved = await state.saveDraft(value, allowDuplicate: allowDuplicate);
    if (!mounted || saved) return;
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
        await state.saveDraft(value, allowDuplicate: true);
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
                  labelText: '链接',
                  prefixIcon: const Icon(Icons.link),
                  suffixIcon: IconButton(
                    onPressed: () => openExternalLink(context, _url.text),
                    tooltip: '打开链接',
                    icon: const Icon(Icons.open_in_new),
                  ),
                ),
                keyboardType: TextInputType.url,
                onChanged: (_) => setState(() {}),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BookmarkCover(
                    sourceUrl: _url.text,
                    coverUrl: _coverUrl.text,
                    width: 88,
                    height: 88,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _coverUrl,
                      decoration: const InputDecoration(
                        labelText: '封面 URL（可选）',
                        prefixIcon: Icon(Icons.image_outlined),
                      ),
                      keyboardType: TextInputType.url,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: _recognizing ? null : _recognizeMetadata,
                  icon: _recognizing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_outlined),
                  label: const Text('识别封面'),
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
                onPressed: state.busy || _recognizing ? null : _save,
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
