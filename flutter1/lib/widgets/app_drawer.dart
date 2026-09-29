import 'package:flutter/material.dart';

import '../features/auth/presentation/auth_page.dart';
import '../features/items/presentation/items_page.dart';
import '../features/folders/presentation/folders_page.dart';
import '../core/auth/session_store.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.token, required this.selected});

  final String token;
  final DrawerSection selected;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const UserAccountsDrawerHeader(
              accountName: Text('鲸境用户'),
              accountEmail: Text('把收藏变成行动'),
              currentAccountPicture: CircleAvatar(child: Text('鲸')),
            ),
            ListTile(
              leading: const Icon(Icons.folder_copy_outlined),
              title: const Text('我的收藏夹'),
              onTap: () => _open(context, FoldersPage(token: token)),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('首页'),
              selected: selected == DrawerSection.home,
              onTap: () => _open(context, HomePage(token: token)),
            ),
            ListTile(
              leading: const Icon(Icons.collections_bookmark_outlined),
              title: const Text('收藏夹'),
              selected: selected == DrawerSection.items,
              onTap: () => _open(context, ItemsPage(token: token)),
            ),
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('退出登录'),
              onTap: () async {
                await SessionStore().clear();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthPage()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => page));
  }
}

enum DrawerSection { home, items }
