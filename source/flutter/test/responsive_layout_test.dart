import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:wwjing_bookmarks/models/bookmark.dart';
import 'package:wwjing_bookmarks/services/api_client.dart';
import 'package:wwjing_bookmarks/state/app_state.dart';
import 'package:wwjing_bookmarks/widgets/folder_navigation.dart';
import 'package:wwjing_bookmarks/widgets/home_page.dart';
import 'package:wwjing_bookmarks/widgets/bookmark_form.dart';
import 'package:wwjing_bookmarks/widgets/bookmark_cover.dart';

import 'test_fakes.dart';

void main() {
  late AppState state;

  setUp(() {
    final tokens = MemoryTokenStore('Bearer token');
    state =
        AppState(
            api: ApiClient(
              baseUrl: 'https://api.example/api',
              tokenStore: tokens,
              httpClient: MockClient((_) async => http.Response('{}', 200)),
            ),
            tokenStore: tokens,
            preferences: MemoryPreferencesStore(),
          )
          ..initialized = true
          ..authenticated = true
          ..folders = const [BookmarkFolder(id: '1', name: '阅读')]
          ..items = const [
            BookmarkItem(
              id: '9',
              sourceUrl: 'https://example.com/article',
              title: '示例收藏',
              sourceHost: 'example.com',
            ),
          ];
  });

  Future<void> pumpHome(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: HomePage()),
      ),
    );
  }

  testWidgets('手机使用抽屉目录导航', (tester) async {
    await pumpHome(tester, const Size(420, 800));
    expect(find.byTooltip('Open navigation menu'), findsOneWidget);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);
    expect(find.byType(FolderNavigation), findsOneWidget);
  });

  testWidgets('宽屏常驻显示目录栏和目录操作入口', (tester) async {
    await pumpHome(tester, const Size(1000, 800));
    expect(find.byType(Drawer), findsNothing);
    expect(find.byType(FolderNavigation), findsOneWidget);
    expect(find.byTooltip('目录操作'), findsOneWidget);
    expect(find.byTooltip('打开链接'), findsOneWidget);
    expect(find.byType(BookmarkCover), findsOneWidget);
    expect(find.byKey(const Key('bookmark-cover-placeholder')), findsOneWidget);
    expect(find.text('example.com'), findsWidgets);
  });

  testWidgets('收藏表单链接框右侧显示打开按钮', (tester) async {
    state.draft = const BookmarkDraft(sourceUrl: 'https://example.com');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: BookmarkForm()),
      ),
    );
    expect(find.byTooltip('打开链接'), findsOneWidget);
    expect(find.text('识别封面'), findsOneWidget);
    expect(find.widgetWithText(TextField, '封面 URL（可选）'), findsOneWidget);
    expect(find.byKey(const Key('bookmark-cover-placeholder')), findsOneWidget);
  });
}
