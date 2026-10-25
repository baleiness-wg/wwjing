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
          ..folders = const [BookmarkFolder(id: '1', name: '阅读')];
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
  });
}
