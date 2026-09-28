import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'features/auth/presentation/auth_page.dart';

class WwjingApp extends StatelessWidget {
  const WwjingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff176b87)),
        useMaterial3: true,
      ),
      home: const AuthPage(),
    );
  }
}
