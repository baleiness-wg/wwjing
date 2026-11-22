import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:io';

import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../components/folder_picker_dialog.dart';
import '../stores/bookmark_state.dart';
import '../viewmodels/bookmark.dart';
import '../utils/link_launcher.dart';
import '../utils/shared_link_parser.dart';
import '../utils/bilibili_resolver.dart';
import '../utils/douyin_resolver.dart';
import '../api/api_client.dart';

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
  Set<String> _folderIds = {};
  List<String> _images = const [];
  List<XFile> _pendingImages = [];
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
    _imageUrl = TextEditingController(
      text: draft.images.isEmpty ? '' : draft.images.first,
    );
    _folderId = draft.folderId;
    _folderIds = draft.folderIds.toSet();
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
      _folderIds = draft.folderIds.toSet();
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

  Future<void> _pickImages() async {
    final files = await ImagePicker().pickMultiImage(imageQuality: 90);
    if (files.isEmpty || !mounted) return;
    setState(() => _pendingImages = [..._pendingImages, ...files]);
  }

  Future<void> _showImages(int initialIndex) async {
    final previewImages = [
      ..._images.map((image) => _PreviewImage.network(image)),
      ..._pendingImages.map((file) => _PreviewImage.file(file.path)),
    ];
    if (previewImages.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            var currentIndex = initialIndex;
            return SizedBox(
              height: MediaQuery.sizeOf(context).height * .72,
              child: Stack(
                children: [
                  PageView.builder(
                    itemCount: previewImages.length,
                    controller: PageController(initialPage: initialIndex),
                    onPageChanged: (index) =>
                        setDialogState(() => currentIndex = index),
                    itemBuilder: (_, index) =>
                        InteractiveViewer(child: previewImages[index].build()),
                  ),
                  Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Text(
                            '${currentIndex + 1} / ${previewImages.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
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
      if (metadata?.finalUrl?.trim().isNotEmpty == true) {
        _url.text = metadata!.finalUrl!.trim();
      }
      if (metadata?.coverUrl?.trim().isNotEmpty == true) {
        _imageUrl.text = metadata!.coverUrl!.trim();
        _images = [
          _imageUrl.text,
          ..._images.where((value) => value != _imageUrl.text),
        ];
      }
      if (_title.text.trim().isEmpty &&
          metadata?.title?.trim().isNotEmpty == true) {
        _title.text = metadata!.title!.trim();
      }
      if (_description.text.trim().isEmpty &&
          metadata?.description?.trim().isNotEmpty == true) {
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
    debugPrint(
      '[BookmarkForm] save start editing=${state.editingItemId != null} images=${_images.length} pendingImages=${_pendingImages.length}',
    );
    final value = BookmarkDraft(
      sourceUrl: sourceUrl,
      title: _title.text.trim(),
      description: _description.text.trim(),
      folderId: _folderId,
      folderIds: _folderIds.toList(),
      images: _images,
    );
    final saved = await state.saveDraft(
      value,
      allowDuplicate: allowDuplicate,
      // 先保存收藏，封面识别完成后再异步回写元数据。
      metadataFuture: _metadataFuture,
      pendingImagePaths: _pendingImages.map((file) => file.path).toList(),
    );
    if (!mounted) return;
    debugPrint(
      '[BookmarkForm] save result saved=$saved itemId=${state.lastSavedItemId} errorCode=${state.errorCode} error=${state.error}',
    );
    if (saved) {
      final itemId = state.lastSavedItemId;
      if (itemId != null) {
        try {
          debugPrint(
            '[BookmarkForm] uploading pending images count=${_pendingImages.length} itemId=$itemId',
          );
          for (final file in _pendingImages) {
            debugPrint('[BookmarkForm] upload start path=${file.path}');
            final images = await state.api.uploadItemImage(itemId, file.path);
            debugPrint(
              '[BookmarkForm] upload success itemId=$itemId savedImages=${images.length}',
            );
          }
          await state.refresh(resetPage: true);
        } on ApiException catch (error) {
          debugPrint(
            '[BookmarkForm] upload failed code=${error.code} status=${error.statusCode} message=${error.message}',
          );
          if (mounted)
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(error.message)));
        }
      }
      return;
    }
    if (state.errorCode == 'DUPLICATE_BOOKMARK') {
      final duplicate = DuplicateBookmarkInfo.fromJson(state.errorData);
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('链接已收藏'),
          content: Text(
            '已有收藏：${duplicate.title?.isNotEmpty == true ? duplicate.title : _url.text.trim()}\n所在位置：${duplicate.folderName ?? '灵感'}',
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
    final selected = await showMultiFolderPicker(
      context: context,
      state: state,
      title: '选择收藏夹',
      selectedFolderIds: _folderIds,
      rootLabel: '灵感',
      allowCreate: true,
    );
    if (!mounted || selected == null) return;
    setState(() {
      _folderIds = selected.toSet();
      _folderId = selected.isEmpty ? null : selected.first;
    });
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
                decoration: const InputDecoration(labelText: '标题（必填）'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
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
                  return value == null ||
                          value.trim().isEmpty ||
                          (uri != null &&
                              uri.hasAuthority &&
                              (uri.scheme == 'http' || uri.scheme == 'https'))
                      ? null
                      : '请输入有效的 HTTP/HTTPS 链接';
                },
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
              const SizedBox(height: 8),
              if (_images.isNotEmpty || _pendingImages.isNotEmpty)
                SizedBox(
                  height: 96,
                  child: ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _images.length + _pendingImages.length,
                    onReorder: (oldIndex, newIndex) => setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final entries = <({String path, bool pending})>[
                        ..._images.map((path) => (path: path, pending: false)),
                        ..._pendingImages.map(
                          (file) => (path: file.path, pending: true),
                        ),
                      ];
                      final entry = entries.removeAt(oldIndex);
                      entries.insert(newIndex, entry);
                      _images = [
                        for (final item in entries)
                          if (!item.pending) item.path,
                      ];
                      _pendingImages = [
                        for (final item in entries)
                          if (item.pending) XFile(item.path),
                      ];
                      _imageUrl.text = _images.firstOrNull ?? '';
                    }),
                    itemBuilder: (_, index) {
                      final isPending = index >= _images.length;
                      final image = isPending
                          ? _pendingImages[index - _images.length].path
                          : _images[index];
                      return GestureDetector(
                        key: ValueKey('$image-$index'),
                        onTap: () => _showImages(index),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: isPending
                                  ? Image.file(
                                      File(image),
                                      width: 96,
                                      height: 96,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.network(
                                      image,
                                      width: 96,
                                      height: 96,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            if (index == 0)
                              Positioned(
                                left: 4,
                                bottom: 4,
                                child: DecoratedBox(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(4),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      '封面',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: IconButton(
                                iconSize: 14,
                                color: Colors.white,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 22,
                                  height: 22,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                ),
                                onPressed: () => setState(() {
                                  if (isPending) {
                                    _pendingImages.removeAt(
                                      index - _images.length,
                                    );
                                  } else {
                                    _images.removeAt(index);
                                  }
                                  _imageUrl.text = _images.firstOrNull ?? '';
                                }),
                                icon: const Icon(Icons.close),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
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
                      label: const Text('识别封面'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('追加图片'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Card.outlined(
                key: const Key('folder-picker-trigger'),
                child: ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: const Text('收藏夹'),
                  subtitle: _folderIds.isEmpty
                      ? const Text('灵感')
                      : Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: [
                            for (final id in _folderIds)
                              InputChip(
                                label: Text(
                                  folderNodes
                                          .where((node) => node.folder.id == id)
                                          .firstOrNull
                                          ?.folder
                                          .name ??
                                      id,
                                ),
                                onDeleted: () => setState(() {
                                  _folderIds.remove(id);
                                  if (_folderId == id) {
                                    _folderId = _folderIds.firstOrNull;
                                  }
                                }),
                              ),
                          ],
                        ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _chooseFolder(folderNodes),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Material(
            elevation: 3,
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.error != null) ...[
                    Text(
                      state.error!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewImage {
  const _PreviewImage.network(this.value) : file = false;
  const _PreviewImage.file(this.value) : file = true;
  final String value;
  final bool file;
  Widget build() => file
      ? Image.file(File(value), fit: BoxFit.contain)
      : Image.network(value, fit: BoxFit.contain);
}
