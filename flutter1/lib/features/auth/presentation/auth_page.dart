import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../items/presentation/items_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _apiClient = ApiClient();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _registerMode = false;
  bool _loading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final credentials = {
        'username': _usernameController.text,
        'password': _passwordController.text,
      };
      if (_registerMode) {
        await _apiClient.post('/api/auth/register', credentials);
      }
      final result = await _apiClient.post('/api/auth/login', credentials);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomePage(token: result['token'] as String),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('鲸境', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(_registerMode ? '创建账号' : '回来继续整理'),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(labelText: '用户名'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: '密码'),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: Text(_loading ? '处理中...' : _registerMode ? '注册并登录' : '登录'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _registerMode = !_registerMode),
                      child: Text(_registerMode ? '已有账号，去登录' : '还没有账号，先注册'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
