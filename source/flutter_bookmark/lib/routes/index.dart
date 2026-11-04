// 管理应用根组件和命名路由。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../constants/app_config.dart';
import '../pages/bookmark_form.dart';
import '../pages/home_page.dart';
import '../pages/login_page.dart';
import '../stores/bookmark_state.dart';
import '../utils/preferences_store.dart';
import '../utils/share_service.dart';
import '../utils/shared_link_parser.dart';
import '../utils/token_store.dart';

// 返回 App 根级组件。
Widget getRootWidget() {
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
  return BookmarkApp(state: state, appConfig: appConfig);
}

// 返回应用的命名路由配置。
Map<String, WidgetBuilder> getRootRoutes(AppConfig appConfig) {
  return {
    '/login': (_) => LoginPage(appConfig: appConfig),
    '/home': (_) => HomePage(appConfig: appConfig),
    '/bookmark-form': (_) => const BookmarkForm(),
  };
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
      final context = _navigatorKey.currentContext;
      if (context != null) {
        final accept = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('检测到新分享链接'),
            content: const Text('当前正在编辑链接，是否放弃当前编辑并切换至新识别到的链接？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('确定切换'),
              ),
            ],
          ),
        );
        if (accept == true) widget.state.openSharedText(text);
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
    if (!widget.state.initialized || !widget.state.authenticated) return;
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    final shared = text == null ? null : extractSharedLink(text);
    if (shared == null ||
        shared.url == await widget.state.preferences.handledClipboardUrl()) {
      return;
    }
    if (!mounted) return;
    if (widget.state.draft != null) {
      final context = _navigatorKey.currentContext;
      if (context != null) {
        await widget.state.preferences.setHandledClipboardUrl(shared.url);
        if (!context.mounted) return;
        final accept = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('检测到新分享链接'),
            content: Text('检测到剪贴板中的新链接：\n${shared.title.isNotEmpty ? shared.title : shared.url}\n\n是否放弃当前编辑并切换至新链接？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('确定切换'),
              ),
            ],
          ),
        );
        if (accept == true) widget.state.openSharedText(text ?? shared.url);
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
    if (accept) await _onIncomingShare(_clipboardText ?? url);
    if (!mounted) return;
    setState(() {
      _clipboardCandidate = null;
      _clipboardText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.state,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: widget.appConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        initialRoute: '/',
        routes: {
          '/': (_) => const _RootPage(),
          ...getRootRoutes(widget.appConfig),
        },
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF006B5F),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}

class _RootPage extends StatelessWidget {
  const _RootPage();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        if (!state.initialized) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!state.authenticated) {
          return LoginPage(appConfig: _appConfig(context));
        }
        if (state.draft != null) return const BookmarkForm();
        return const _HomeWithClipboard();
      },
    );
  }

  AppConfig _appConfig(BuildContext context) =>
      context.findAncestorStateOfType<_BookmarkAppState>()!.widget.appConfig;
}

class _HomeWithClipboard extends StatelessWidget {
  const _HomeWithClipboard();

  @override
  Widget build(BuildContext context) {
    final app = context.findAncestorStateOfType<_BookmarkAppState>();
    return Scaffold(
      body: HomePage(appConfig: app!.widget.appConfig),
      bottomNavigationBar: app._clipboardCandidate == null
          ? null
          : Material(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Expanded(child: Text('剪贴板中发现新链接，是否收藏？')),
                      TextButton(
                        onPressed: () => app._handleClipboard(false),
                        child: const Text('忽略'),
                      ),
                      FilledButton(
                        onPressed: () => app._handleClipboard(true),
                        child: const Text('打开'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
