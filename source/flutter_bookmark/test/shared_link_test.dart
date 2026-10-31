import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wwjing_bookmark/config/app_config.dart';
import 'package:wwjing_bookmark/main.dart';
import 'package:wwjing_bookmark/models/bookmark.dart';
import 'package:wwjing_bookmark/models/shared_link.dart';
import 'package:wwjing_bookmark/services/api_client.dart';
import 'package:wwjing_bookmark/services/share_service.dart';
import 'package:wwjing_bookmark/state/app_state.dart';
import 'package:wwjing_bookmark/widgets/bookmark_form.dart';
import 'test_fakes.dart';

class FakeShareService extends ShareService {
  FakeShareService({this.onListen});
  final void Function(void Function(String))? onListen;

  @override
  void listen(void Function(String) callback) {
    onListen?.call(callback);
  }

  @override
  Future<String?> initialText() async => null;
}

void main() {
  test('提取混合文本中的首个 HTTP 链接并保留原文', () {
    const text = '看看这个：https://Example.com/a，备用 https://second.example';
    final result = extractSharedLink(text);
    expect(result?.url, 'https://Example.com/a');
    expect(result?.title, '看看这个：');
    expect(result?.originalText, text);
  });

  test('从抖音分享文案提取作品标题而不是域名', () {
    const text =
        '8.23 复制打开抖音，看看【Senven的图文作品】旅行自由。Hi guys. Today I wan... https://v.douyin.com/5vmPboOhNmQ/ :5pm u@f.bn YMW:/ 08/09';
    final result = extractSharedLink(text);
    expect(result?.url, 'https://v.douyin.com/5vmPboOhNmQ/');
    expect(result?.title, '旅行自由。Hi guys. Today I wan...');
  });

  test('从小红书分享文案提取笔记标题', () {
    const text =
        '动词-英语易混动词，一次分清 lie / lay、rise / rais... https://xhslink.cn/o/8ATAEclrdQd 先复制内容，然后去【小红书】一键查看笔记。';
    final result = extractSharedLink(text);
    expect(result?.title, '动词-英语易混动词，一次分清 lie / lay、rise / rais...');
  });

  test('忽略无链接和非 HTTP 协议', () {
    expect(extractSharedLink('只有中文'), isNull);
    expect(extractSharedLink('ftp://example.com/a'), isNull);
  });

  testWidgets('编辑状态下接收新分享链接弹出确认对话框', (tester) async {
    final tokens = MemoryTokenStore('Bearer token');
    final state = AppState(
      api: ApiClient(
        baseUrl: 'https://api.example/api',
        space: 'cookie',
        tokenStore: tokens,
      ),
      tokenStore: tokens,
      preferences: MemoryPreferencesStore(),
    )
      ..initialized = true
      ..authenticated = true
      ..draft = const BookmarkDraft(sourceUrl: 'https://old.example.com');

    void Function(String)? shareCallback;
    final app = BookmarkApp(
      state: state,
      appConfig: AppConfig.kitchen,
      shareService: FakeShareService(
        onListen: (cb) => shareCallback = cb,
      ),
    );

    await tester.pumpWidget(app);
    await tester.pump();
    expect(find.byType(BookmarkForm), findsOneWidget);

    // 触发新链接
    shareCallback?.call('https://new.example.com');
    await tester.pump();

    // 弹出确认对话框
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('检测到新分享链接'), findsOneWidget);
    expect(find.text('确定切换'), findsOneWidget);

    // 点击确定切换
    await tester.tap(find.text('确定切换'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(state.draft?.sourceUrl, 'https://new.example.com');
  });
}
