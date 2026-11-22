import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_config.dart';
import '../stores/bookmark_state.dart';

class MyPage extends StatelessWidget {
  const MyPage({
    super.key,
    required this.appConfig,
    required this.onOpenFolders,
  });

  final AppConfig appConfig;
  final VoidCallback onOpenFolders;

  Future<void> _changePassword(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    try {
      final values = await showDialog<List<String>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('修改密码'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(labelText: '当前密码'),
              ),
              TextField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(labelText: '新密码'),
              ),
              TextField(
                controller: confirm,
                obscureText: true,
                decoration: const InputDecoration(labelText: '确认新密码'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, [
                current.text,
                next.text,
                confirm.text,
              ]),
              child: const Text('确认修改'),
            ),
          ],
        ),
      );
      if (values == null || !context.mounted) return;
      if (values.any((value) => value.isEmpty)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('请填写完整密码信息')));
        return;
      }
      if (values[1] != values[2]) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('两次输入的新密码不一致')));
        return;
      }
      await context.read<AppState>().changePassword(
        values[0],
        values[1],
        values[2],
      );
    } finally {
      current.dispose();
      next.dispose();
      confirm.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text('我的设置', style: TextStyle(fontSize: 20)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('修改密码'),
                onTap: () async {
                  Navigator.pop(context);
                  await _changePassword(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('退出登录'),
                onTap: () => context.read<AppState>().logout(),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('收藏夹目录'),
              subtitle: Text('${state.folders.length} 个目录'),
              onTap: onOpenFolders,
            ),
          ),
        ],
      ),
    );
  }
}
