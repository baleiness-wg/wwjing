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
                onTap: () => Navigator.pop(context),
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
