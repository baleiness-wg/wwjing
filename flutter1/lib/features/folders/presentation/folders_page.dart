import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../models/folder.dart';
import '../../items/presentation/items_page.dart';

class FoldersPage extends StatefulWidget {
  const FoldersPage({super.key, required this.token});
  final String token;

  @override
  State<FoldersPage> createState() => _FoldersPageState();
}

class _FoldersPageState extends State<FoldersPage> {
  final _apiClient = ApiClient();
  final _nameController = TextEditingController();
  List<Folder> _folders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadFolders() async {
    try {
      final result = await _apiClient.get('/api/folders', token: widget.token);
      final folders = (result['folders'] as List<dynamic>)
          .map((item) => Folder.fromJson(item as Map<String, dynamic>))
          .toList();
      if (mounted) setState(() => _folders = folders);
    } catch (error) {
      _showError('收藏夹接口不可用，请先部署后端并执行数据库迁移');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createFolder() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    try {
      final result = await _apiClient.post('/api/folders', {
        'name': name,
      }, token: widget.token);
      setState(() {
        _folders.add(Folder.fromJson(result['folder'] as Map<String, dynamic>));
        _nameController.clear();
      });
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: '返回',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: const Text('我的收藏夹'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '新收藏夹名称'),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: _createFolder,
              icon: const Icon(Icons.add),
              tooltip: '新建收藏夹',
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (!_loading && _folders.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('暂时没有收藏夹目录。请先部署服务端收藏夹接口，或新建一个收藏夹。'),
            ),
          ),
        for (final folder in _folders)
          Card(
            child: ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(folder.name),
              subtitle: Text('${folder.itemCount} 条收藏'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ItemsPage(token: widget.token, folder: folder),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
