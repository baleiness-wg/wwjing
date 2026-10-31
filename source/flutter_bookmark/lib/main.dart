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

// BUILD_TIME: 2026/10/31 19:27
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final appConfig = AppConfig.current;
  final tokenStore = SecureTokenStore();
  late final AppState state;
  final api = ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    space: appConfig.space,
    tokenStore: tokenStore,
    onUnauthorized: () => state.handleUnauthorized(),
  );
  state = AppState(
    api: api,
    tokenStore: tokenStore,
    preferences: SharedPreferencesStore(),
  );
  runApp(BookmarkApp(state: state, appConfig: appConfig));
}

class BookmarkApp extends StatefulWidget {
  const BookmarkApp({
    super.key,
    required this.state,
    required this.appConfig,
    this.shareService,
  });

  final AppState state;
  final AppConfig appConfig;
  final ShareService? shareService;

  @override
  State<BookmarkApp> createState() => _BookmarkAppState();
}

class _BookmarkAppState extends State<BookmarkApp> with WidgetsBindingObserver {
  late final ShareService _shareService;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  String? _clipboardCandidate;
  String? _clipboardText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shareService = widget.shareService ?? ShareService();
    _shareService.listen(_onIncomingShare);
    widget.state.initialize().then((_) async {
      try {
        final initial = await _shareService.initialText();
        if (initial != null) _onIncomingShare(initial);
      } on PlatformException {
        // 非 Android 测试环境不提供分享通道。
      }
      await _checkClipboard();
    });
  }

  Future<void> _onIncomingShare(String text) async {
    if (widget.state.draft != null) {
      final navContext = _navigatorKey.currentContext;
      if (navContext != null) {
        final accept = await showDialog<bool>(
          context: navContext,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('检测到新分享链接'),
            content: const Text('当前正在编辑链接，是否放弃当前编辑并切换至新识别到的链接？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('确定切换'),
              ),
            ],
          ),
        );
        if (accept == true) {
          widget.state.openSharedText(text);
        }
        return;
      }
    }
    widget.state.openSharedText(text);
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
    if (!widget.state.initialized || !widget.state.authenticated) {
      return;
    }
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    final shared = text == null ? null : extractSharedLink(text);
    if (shared == null ||
        shared.url == await widget.state.preferences.handledClipboardUrl()) {
      return;
    }
    if (!mounted) return;

    // 如果当前正在编辑表单界面，直接弹出确认弹窗，不吞没！
    if (widget.state.draft != null) {
      final navContext = _navigatorKey.currentContext;
      if (navContext != null) {
        await widget.state.preferences.setHandledClipboardUrl(shared.url);
        if (!navContext.mounted) return;
        final accept = await showDialog<bool>(
          context: navContext,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('检测到新分享链接'),
            content: Text('检测到剪贴板中的新链接：\n${shared.title.isNotEmpty ? shared.title : shared.url}\n\n是否放弃当前编辑并切换至新链接？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('确定切换'),
              ),
            ],
          ),
        );
        if (accept == true) {
          widget.state.openSharedText(text ?? shared.url);
        }
      }
      return;
    }

    setState(() {
      _clipboardCandidate = shared.url;
      _clipboardText = text;
    });
  }

  Future<void> _handleClipboard(bool accept) async {
    final url = _clipboardCandidate;
    if (url == null) return;
    await widget.state.preferences.setHandledClipboardUrl(url);
    if (accept) {
      await _onIncomingShare(_clipboardText ?? url);
    }
    if (mounted) {
      setState(() {
        _clipboardCandidate = null;
        _clipboardText = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.state,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: widget.appConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF006B5F),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          textTheme: ThemeData.light().textTheme.copyWith(
            bodyLarge: const TextStyle(fontSize: 14),
            bodyMedium: const TextStyle(fontSize: 13),
            bodySmall: const TextStyle(fontSize: 11),
            labelLarge: const TextStyle(fontSize: 13),
            labelMedium: const TextStyle(fontSize: 11),
            labelSmall: const TextStyle(fontSize: 10),
            titleLarge: const TextStyle(fontSize: 20),
            titleMedium: const TextStyle(fontSize: 16),
            titleSmall: const TextStyle(fontSize: 14),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
          cardTheme: CardThemeData(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          listTileTheme: const ListTileThemeData(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ),
        ),
        home: Consumer<AppState>(
          builder: (context, state, _) {
            if (!state.initialized) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (!state.authenticated) {
              return LoginPage(appConfig: widget.appConfig);
            }
            if (state.draft != null) return const BookmarkForm();
            return Scaffold(
              body: HomePage(appConfig: widget.appConfig),
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
