import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'models/shared_link.dart';
import 'services/api_client.dart';
import 'services/preferences_store.dart';
import 'services/share_service.dart';
import 'services/token_store.dart';
import 'state/app_state.dart';
import 'widgets/bookmark_form.dart';
import 'widgets/home_page.dart';
import 'widgets/login_page.dart';

// BUILD_TIME: 2026/10/26 02:09
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final tokenStore = SecureTokenStore();
  late final AppState state;
  final api = ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    tokenStore: tokenStore,
    onUnauthorized: () => state.handleUnauthorized(),
  );
  state = AppState(
    api: api,
    tokenStore: tokenStore,
    preferences: SharedPreferencesStore(),
  );
  runApp(BookmarkApp(state: state));
}

class BookmarkApp extends StatefulWidget {
  const BookmarkApp({super.key, required this.state, this.shareService});

  final AppState state;
  final ShareService? shareService;

  @override
  State<BookmarkApp> createState() => _BookmarkAppState();
}

class _BookmarkAppState extends State<BookmarkApp> with WidgetsBindingObserver {
  late final ShareService _shareService;
  String? _clipboardCandidate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shareService = widget.shareService ?? ShareService();
    _shareService.listen(widget.state.openSharedText);
    widget.state.initialize().then((_) async {
      try {
        final initial = await _shareService.initialText();
        if (initial != null) widget.state.openSharedText(initial);
      } on PlatformException {
        // 非 Android 测试环境不提供分享通道。
      }
      await _checkClipboard();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkClipboard();
  }

  Future<void> _checkClipboard() async {
    if (!widget.state.initialized ||
        !widget.state.authenticated ||
        widget.state.draft != null) {
      return;
    }
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    final shared = text == null ? null : extractSharedLink(text);
    if (shared == null ||
        shared.url == await widget.state.preferences.handledClipboardUrl()) {
      return;
    }
    if (!mounted) return;
    setState(() => _clipboardCandidate = shared.url);
  }

  Future<void> _handleClipboard(bool accept) async {
    final url = _clipboardCandidate;
    if (url == null) return;
    await widget.state.preferences.setHandledClipboardUrl(url);
    if (accept) widget.state.openSharedText(url);
    if (mounted) setState(() => _clipboardCandidate = null);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.state,
      child: MaterialApp(
        title: '微微鲸收藏',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF006B5F),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
          cardTheme: const CardThemeData(margin: EdgeInsets.zero),
        ),
        home: Consumer<AppState>(
          builder: (context, state, _) {
            if (!state.initialized) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (!state.authenticated) return const LoginPage();
            if (state.draft != null) return const BookmarkForm();
            return Scaffold(
              body: const HomePage(),
              bottomNavigationBar: _clipboardCandidate == null
                  ? null
                  : Material(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              const Expanded(child: Text('剪贴板中发现新链接，是否收藏？')),
                              TextButton(
                                onPressed: () => _handleClipboard(false),
                                child: const Text('忽略'),
                              ),
                              FilledButton(
                                onPressed: () => _handleClipboard(true),
                                child: const Text('打开'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }
}
