import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../state/app_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.appConfig});

  final AppConfig? appConfig;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _isRegisterMode = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _username.text.trim();
    final password = _password.text;
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isRegisterMode ? '请输入用户名和密码' : '请输入用户名和密码登录')),
      );
      return;
    }

    if (_isRegisterMode) {
      final confirmPassword = _confirmPassword.text;
      if (password != confirmPassword) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('两次输入的密码不一致')));
        return;
      }
      await context.read<AppState>().register(username, password);
    } else {
      await context.read<AppState>().login(username, password);
    }
  }

  void _toggleMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _confirmPassword.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final effectiveAppName =
        widget.appConfig?.appName ??
        (const String.fromEnvironment('APP_TYPE').isNotEmpty
            ? AppConfig.current.appName
            : '鲸界');
    final isKitchen =
        widget.appConfig?.type == AppType.kitchen ||
        (widget.appConfig == null &&
            const String.fromEnvironment('APP_TYPE') == 'kitchen');
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        isKitchen
                            ? Icons.restaurant_rounded
                            : Icons.water_drop_rounded,
                        size: 52,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _isRegisterMode ? '注册账号' : effectiveAppName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _username,
                        autofillHints: const [AutofillHints.username],
                        decoration: const InputDecoration(
                          labelText: '用户名',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) {
                          if (!_isRegisterMode) _submit();
                        },
                        decoration: const InputDecoration(
                          labelText: '密码',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                      if (_isRegisterMode) ...[
                        const SizedBox(height: 14),
                        TextField(
                          key: const Key('confirm-password-field'),
                          controller: _confirmPassword,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(
                            labelText: '确认密码',
                            prefixIcon: Icon(Icons.lock_reset_outlined),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        key: _isRegisterMode
                            ? const Key('submit-register-button')
                            : const Key('login-button'),
                        onPressed: state.busy ? null : _submit,
                        child: Text(_isRegisterMode ? '立即注册' : '登录'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isRegisterMode ? '已有账号？' : '还没有账号？',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          TextButton(
                            key: const Key('switch-mode-button'),
                            onPressed: state.busy ? null : _toggleMode,
                            child: Text(_isRegisterMode ? '去登录' : '立即注册'),
                          ),
                        ],
                      ),
                      if (state.draft != null) ...[
                        const SizedBox(height: 12),
                        const Text(
                          '登录后将恢复待保存的收藏。',
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (state.error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          state.error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
