import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:wwjing_bookmark/models/bookmark.dart';
import 'package:wwjing_bookmark/config/app_config.dart';
import 'package:wwjing_bookmark/services/api_client.dart';
import 'package:wwjing_bookmark/services/link_launcher.dart';
import 'package:wwjing_bookmark/state/app_state.dart';
import 'package:wwjing_bookmark/widgets/folder_navigation.dart';
import 'package:wwjing_bookmark/widgets/home_page.dart';
import 'package:wwjing_bookmark/widgets/bookmark_form.dart';
import 'package:wwjing_bookmark/widgets/bookmark_cover.dart';
import 'package:wwjing_bookmark/widgets/bookmark_item_card.dart';

import 'test_fakes.dart';

class RecordingLinkLauncher extends LinkLauncher {
  RecordingLinkLauncher();

  String? openedUrl;

  @override
  Future<bool> open(BuildContext context, String value) async {
    openedUrl = value;
    return true;
  }
}

void main() {
  late AppState state;

  setUp(() {
    final tokens = MemoryTokenStore('Bearer token');
    state =
        AppState(
            api: ApiClient(
              baseUrl: 'https://api.example/api',
              space: 'cookie',
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
        child: const MaterialApp(home: HomePage(appConfig: AppConfig.kitchen)),
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
    expect(find.byTooltip('更多操作'), findsOneWidget);
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

  testWidgets('共享收藏卡片按模式显示选择和操作控件', (tester) async {
    const item = BookmarkItem(
      id: '1',
      sourceUrl: 'https://example.com',
      title: '示例',
      sourceHost: 'example.com',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            BookmarkItemCard(
              item: item,
              selectionValue: false,
              onSelectionChanged: (_) {},
              onAction: (_) {},
              onTap: () {},
            ),
            BookmarkItemCard(item: item, onTap: () {}),
          ],
        ),
      ),
    );

    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.byTooltip('更多操作'), findsOneWidget);
    expect(find.byType(BookmarkCover), findsNWidgets(2));
  });

  testWidgets('kitchen 显示随机弹窗且 star 隐藏随机入口', (tester) async {
    final tokens = MemoryTokenStore('Bearer token');
    state =
        AppState(
            api: ApiClient(
              baseUrl: 'https://api.example/api',
              space: 'cookie',
              tokenStore: tokens,
              httpClient: MockClient((request) async {
                if (request.url.path.endsWith('/random')) {
                  return http.Response.bytes(
                    utf8.encode(
                      '{"item":{"id":"7","sourceUrl":"https://example.com/meal","title":"晚餐","sourceHost":"example.com"}}',
                    ),
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8',
                    },
                  );
                }
                return http.Response('{}', 200);
              }),
            ),
            tokenStore: tokens,
            preferences: MemoryPreferencesStore(),
          )
          ..initialized = true
          ..authenticated = true;
    final launcher = RecordingLinkLauncher();
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          home: HomePage(appConfig: AppConfig.kitchen, linkLauncher: launcher),
        ),
      ),
    );
    expect(find.byKey(const Key('random-bookmark-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('random-bookmark-button')));
    await tester.pumpAndSettle();
    expect(find.text('今天吃什么'), findsOneWidget);
    expect(find.text('晚餐'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byTooltip('更多操作'), findsNothing);
    final contentSize = tester.getSize(
      find.byKey(const Key('random-bookmark-content')),
    );
    expect(contentSize.height, lessThanOrEqualTo(150));
    await tester.tap(find.text('晚餐'));
    await tester.pump();
    expect(launcher.openedUrl, 'https://example.com/meal');

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: HomePage(appConfig: AppConfig.star)),
      ),
    );
    expect(find.byKey(const Key('random-bookmark-button')), findsNothing);
  });
}
