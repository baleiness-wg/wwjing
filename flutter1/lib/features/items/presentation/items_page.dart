import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../models/item.dart';
import '../../../widgets/app_drawer.dart';

class ItemsPage extends StatefulWidget {
  const ItemsPage({super.key, required this.token});

  final String token;

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  final _apiClient = ApiClient();
  final _titleController = TextEditingController();
  final _nextActionController = TextEditingController();
  final _sourceUrlController = TextEditingController();
  List<Item> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
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
      final result = await _apiClient.get('/api/items', token: widget.token);
      final rawItems = result['items'] as List<dynamic>;
      if (mounted) {
        setState(() => _items = rawItems.map((item) => Item.fromJson(item)).toList());
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addItem() async {
    if (_titleController.text.trim().isEmpty) return;
    try {
      final result = await _apiClient.post(
        '/api/items',
        {
          'title': _titleController.text,
          'nextAction': _nextActionController.text,
          'sourceUrl': _sourceUrlController.text,
        },
        token: widget.token,
      );
      setState(() {
        _items = [Item.fromJson(result['item']), ..._items];
        _titleController.clear();
        _nextActionController.clear();
        _sourceUrlController.clear();
      });
    } catch (error) {
      _showError(error);
    }
  }

  void _showError(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('鲸境收藏夹'),
      ),
      drawer: AppDrawer(token: widget.token, selected: DrawerSection.items),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: '想收进来的内容'),
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
          for (final item in _items)
            Card(
              child: ListTile(
                title: Text(item.title),
                subtitle: Text(
                  item.nextAction.isNotEmpty ? item.nextAction : '还没有下一步动作',
                ),
              ),
            ),
        ],
      ),
    );
  }

}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('鲸境')),
      drawer: AppDrawer(token: token, selected: DrawerSection.home),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('内容工作台', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text('别让收藏替你假装完成。', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          const Text('把随手收藏的内容，变成一件有下一步、会被重新问起的事。'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => ItemsPage(token: token)),
            ),
            icon: const Icon(Icons.collections_bookmark_outlined),
            label: const Text('查看我的收藏'),
          ),
        ],
      ),
    );
  }
}
