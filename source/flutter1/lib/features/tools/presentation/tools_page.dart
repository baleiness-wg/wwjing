import 'package:flutter/material.dart';

import '../../../core/auth/session_store.dart';
import '../../../features/auth/presentation/auth_page.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  Future<void> _logout(BuildContext context) async {
    await SessionStore().clear();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tool'),
        actions: [
          IconButton(
            tooltip: '退出登录',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('个人工具箱', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          const Text('这里将集中放置你的个人工具。'),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.build_outlined),
              title: const Text('Tool'),
              subtitle: const Text('工具目录正在搭建中'),
            ),
          ),
        ],
      ),
    );
  }
}
