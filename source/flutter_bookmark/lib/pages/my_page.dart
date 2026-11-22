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

  Future<void> _editProfile(BuildContext context) async {
    final state = context.read<AppState>();
    final controller = TextEditingController(text: state.profileDescription);
    try {
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => _ProfilePage(controller: controller)),
      );
      if (saved == true) state.profileDescription = controller.text.trim();
    } finally {
      controller.dispose();
    }
  }

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
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              const Expanded(child: SizedBox()),
              Align(
                alignment: Alignment.centerLeft,
                child: PopupMenuButton<String>(
                  tooltip: '设置',
                  icon: const Icon(Icons.settings_outlined),
                  padding: const EdgeInsets.all(16),
                  onSelected: (action) async {
                    if (action == 'password') {
                      Navigator.pop(context);
                      await _changePassword(context);
                    }
                    if (action == 'logout') {
                      await context.read<AppState>().logout();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'password',
                      child: ListTile(
                        leading: Icon(Icons.lock_outline),
                        title: Text('修改密码'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'logout',
                      child: ListTile(
                        leading: Icon(Icons.logout),
                        title: Text('退出登录'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(title: const Text('我的')),
      body: const SizedBox.expand(),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton.extended(
          onPressed: () => _editProfile(context),
          icon: const Icon(Icons.person_outline),
          label: const Text('个人信息'),
        ),
      ),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage({required this.controller});
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('个人信息')),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(
            controller: controller,
            expands: true,
            maxLines: null,
            minLines: null,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              labelText: '个人描述',
              hintText: '告诉 AI 你的兴趣、习惯、目标和偏好',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              await context.read<AppState>().api.updateProfileDescription(
                controller.text.trim(),
              );
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
}
