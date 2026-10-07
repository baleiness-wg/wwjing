import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_client.dart';
import '../../../models/favorite_detail.dart';
import '../../../models/folder.dart';
import '../../../widgets/app_drawer.dart';

String? _lastDetectedClipboardUrl;

class ItemsPage extends StatefulWidget {
  const ItemsPage({super.key, required this.token, this.folder});

  final String token;
  final Folder? folder;

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  final _apiClient = ApiClient();
  final _titleController = TextEditingController();
  final _nextActionController = TextEditingController();
  final _sourceUrlController = TextEditingController();
  List<FavoriteDetail> _items = [];
  bool _loading = true;
  String _category = 'other';
  List<Folder> _folders = [];
  int? _folderId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadItems();
      await _loadFolders();
      if (mounted) await _checkClipboardLink();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _nextActionController.dispose();
    _sourceUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    try {
      final path = widget.folder == null || widget.folder!.id <= 0
          ? '/api/favorite-details'
          : '/api/favorite-details?folderId=${widget.folder!.id}';
      final result = await _apiClient.get(path, token: widget.token);
      final rawItems = result['favoriteDetails'] as List<dynamic>;
      if (mounted) {
        setState(
          () => _items = rawItems.map((item) => FavoriteDetail.fromJson(item)).toList(),
        );
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadFolders() async {
    try {
      final result = await _apiClient.get('/api/folders', token: widget.token);
      final folders = (result['folders'] as List<dynamic>)
          .map((item) => Folder.fromJson(item as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _folders = folders;
          _folderId = widget.folder?.id;
        });
      }
    } catch (error) {
      if (mounted) _showError('加载收藏夹失败：$error');
    }
  }

  Future<void> _addItem() async {
    if (_titleController.text.trim().isEmpty && _sourceUrlController.text.trim().isEmpty) return;
    try {
      final result = await _apiClient.post('/api/favorite-details', {
        'title': _titleController.text,
        'description': '',
        'nextAction': _nextActionController.text,
        'sourceUrl': _sourceUrlController.text,
        'category': _category,
        'folderId': _realFolderId,
      }, token: widget.token);
      setState(() {
        _items = [FavoriteDetail.fromJson(result['favoriteDetail']), ..._items];
        _titleController.clear();
        _nextActionController.clear();
        _sourceUrlController.clear();
        _category = 'other';
      });
    } catch (error) {
      _showError(error);
    }
  }

  int? get _realFolderId {
    final id = widget.folder?.id ?? _folderId;
    return id;
  }

  Future<void> _readClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      _showError('剪切板没有可识别的文字内容');
      return;
    }
    final url = _extractUrl(text);
    final isUrl = url != null;
    final isCode =
        text.contains('```') ||
        RegExp(r'(^|\n)\s*(class|const|function|import|def)\s').hasMatch(text);
    setState(() {
      _titleController.text = isUrl ? '' : text;
      _sourceUrlController.text = url ?? '';
      _category = isUrl
          ? 'link'
          : isCode
          ? 'code'
          : 'text';
      if (_nextActionController.text.isEmpty) {
        _nextActionController.text = isUrl ? '打开链接并整理重点' : '重新阅读并写下下一步';
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已识别为${_categoryLabel(_category)}，确认后加入收藏夹')),
      );
    }
  }

  Future<void> _checkClipboardLink() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    final url = text == null ? null : _extractUrl(text);
    if (!mounted || url == null || url == _lastDetectedClipboardUrl) return;
    _lastDetectedClipboardUrl = url;

    var dialogCategory = 'shopping';
    var dialogFolderId = widget.folder?.id ?? _folderId;
    final category = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发现剪切板链接'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('检测到链接：\n$url'),
              const SizedBox(height: 16),
              DropdownButton<String>(
                value: dialogCategory,
                hint: const Text('保存到类型'),
                items: _categoryOptions
                    .map(
                      (option) => DropdownMenuItem(
                        value: option.$1,
                        child: Text(option.$2),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setDialogState(() {
                  if (value != null) {
                    dialogCategory = value;
                  }
                }),
              ),
              if (_folders.isNotEmpty)
                DropdownButton<int>(
                  value: dialogFolderId,
                  hint: const Text('保存到收藏夹'),
                  items: _folders
                      .map(
                        (folder) => DropdownMenuItem(
                          value: folder.id,
                          child: Text('收藏夹：${folder.name}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() {
                    dialogFolderId = value;
                  }),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('暂不保存'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, dialogCategory),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (category == null || !mounted) return;

      _titleController.text = '';
    _sourceUrlController.text = url;
    _category = category;
    _folderId = dialogFolderId;
    _nextActionController.text = '打开链接并整理重点';
    await _addItem();
  }

  String _categoryLabel(String category) {
    for (final option in _categoryOptions) {
      if (option.$1 == category) return option.$2;
    }
    return '其他';
  }

  void _showError(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.folder?.name ?? '收藏内容')),
      drawer: AppDrawer(token: widget.token, selected: DrawerSection.items),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: '想收进来的内容'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _readClipboard,
                icon: const Icon(Icons.content_paste),
                label: const Text('识别剪切板'),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _category,
                items: _categoryOptions
                    .map(
                      (option) => DropdownMenuItem(
                        value: option.$1,
                        child: Text('分类：${option.$2}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _category = value;
                    });
                  }
                },
              ),
              if (_folders.isNotEmpty)
                DropdownButton<int>(
                  value: _folderId,
                  hint: const Text('选择收藏夹'),
                  items: _folders
                      .map(
                        (folder) => DropdownMenuItem(
                          value: folder.id,
                          child: Text('收藏夹：${folder.name}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _folderId = value),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nextActionController,
            decoration: const InputDecoration(labelText: '下一步动作'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sourceUrlController,
            decoration: const InputDecoration(labelText: '来源链接（可选）'),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _addItem, child: const Text('加入收藏夹')),
          const SizedBox(height: 24),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (!_loading && _items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('还没有收藏内容。复制一个链接，或在上方填写内容后保存。'),
              ),
            ),
          for (final item in _items)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Chip(label: Text(_categoryLabel(item.category))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (item.description.isNotEmpty)
                      Text(
                        item.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      item.nextAction.isNotEmpty
                          ? '下一步：${item.nextAction}'
                          : '还没有下一步动作',
                    ),
                    if (item.sourceUrl.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.sourceUrl,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const _categoryOptions = [
  ('shopping', '购物'),
  ('article', '文章'),
  ('video', '视频'),
  ('code', '代码'),
  ('link', '链接'),
  ('text', '普通文本'),
  ('other', '其他'),
];

String? _extractUrl(String text) {
  final match = RegExp(
    r"(?:(?:https?://)|(?:www\.))[\w\-._~:/?#\[\]@!$&'()*+,;=%]+",
    caseSensitive: false,
  ).firstMatch(text);
  if (match == null) return null;

  var url = match.group(0)!.replaceFirst(RegExp(r'[，。！？；：、）》】\]}]+$'), '');
  if (url.toLowerCase().startsWith('www.')) url = 'https://$url';
  final uri = Uri.tryParse(url);
  return uri != null && uri.host.isNotEmpty ? url : null;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.token});

  final String token;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _apiClient = ApiClient();
  List<Folder> _folders = [];
  int? _folderId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadFolders();
      if (mounted) await _checkClipboardLink();
    });
  }

  Future<void> _loadFolders() async {
    try {
      final result = await _apiClient.get('/api/folders', token: widget.token);
      final folders = (result['folders'] as List<dynamic>)
          .map((item) => Folder.fromJson(item as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _folders = folders;
          _folderId = folders.isEmpty ? null : folders.first.id;
        });
      }
    } catch (_) {
      // The old server will use its default folder.
    }
  }

  Future<void> _checkClipboardLink() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    final url = text == null ? null : _extractUrl(text);
    if (!mounted || url == null || url == _lastDetectedClipboardUrl) return;
    _lastDetectedClipboardUrl = url;
    var dialogCategory = 'shopping';
    var dialogFolderId = _folderId;
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('发现剪切板链接'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('检测到链接：\n$url'),
              const SizedBox(height: 16),
              DropdownButton<String>(
                value: dialogCategory,
                hint: const Text('保存到类型'),
                items: _categoryOptions
                    .map(
                      (option) => DropdownMenuItem(
                        value: option.$1,
                        child: Text('保存到：${option.$2}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setDialogState(() {
                  if (value != null) dialogCategory = value;
                }),
              ),
              if (_folders.isNotEmpty)
                DropdownButton<int>(
                  value: dialogFolderId,
                  hint: const Text('保存到收藏夹'),
                  items: _folders
                      .map(
                        (folder) => DropdownMenuItem(
                          value: folder.id,
                          child: Text('收藏夹：${folder.name}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() {
                    dialogFolderId = value;
                  }),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('暂不保存'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (shouldSave != true || !mounted) return;
    try {
      await _apiClient.post('/api/favorite-details', {
        'title': '',
        'description': '',
        'sourceUrl': url,
        'nextAction': '打开链接并整理重点',
        'category': dialogCategory,
        'folderId': dialogFolderId,
      }, token: widget.token);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('链接已保存到收藏夹')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('鲸境')),
      drawer: AppDrawer(token: widget.token, selected: DrawerSection.home),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('内容工作台', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(
            '别让收藏替你假装完成。',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          const Text('把随手收藏的内容，变成一件有下一步、会被重新问起的事。'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => ItemsPage(token: widget.token)),
            ),
            icon: const Icon(Icons.collections_bookmark_outlined),
            label: const Text('查看我的收藏'),
          ),
        ],
      ),
    );
  }
}
