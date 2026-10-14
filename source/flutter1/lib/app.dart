import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'core/auth/session_store.dart';
import 'features/auth/presentation/auth_page.dart';
import 'features/tools/presentation/tools_page.dart';

class WwjingApp extends StatefulWidget {
  const WwjingApp({super.key});

  @override
  State<WwjingApp> createState() => _WwjingAppState();
}

class _WwjingAppState extends State<WwjingApp> {
  final _sessionStore = SessionStore();
  late final Future<String?> _token = _sessionStore.readToken();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff176b87)),
        useMaterial3: true,
      ),
      home: FutureBuilder<String?>(
        future: _token,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final token = snapshot.data;
          return token == null ? const AuthPage() : const ToolsPage();
        },
      ),
    );
  }
}
