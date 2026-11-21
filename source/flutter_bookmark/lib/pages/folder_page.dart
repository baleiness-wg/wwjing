import 'package:flutter/material.dart';

import '../constants/app_config.dart';
import 'folder_navigation.dart';

class FolderPage extends StatelessWidget {
  const FolderPage({super.key, required this.appConfig});

  final AppConfig appConfig;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('收藏夹目录')),
      body: FolderNavigation(appConfig: appConfig),
    );
  }
}
