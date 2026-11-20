import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_config.dart';
import '../stores/bookmark_state.dart';
import 'inspiration_library_page.dart';

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
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.lightbulb_outline)),
              title: const Text('灵感库'),
              subtitle: const Text('随时记下想法，并关联到收藏夹目录'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InspirationLibraryPage(appConfig: appConfig),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
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
