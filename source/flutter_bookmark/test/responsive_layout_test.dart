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
import 'package:wwjing_bookmark/widgets/folder_picker_dialog.dart';
import 'package:wwjing_bookmark/widgets/home_page.dart';
import 'package:wwjing_bookmark/widgets/bookmark_form.dart';
import 'package:wwjing_bookmark/widgets/bookmark_cover.dart';
import 'package:wwjing_bookmark/widgets/bookmark_item_card.dart';
import 'package:wwjing_bookmark/widgets/login_page.dart';

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
    expect(find.text('疯狂的厨房'), findsOneWidget);
  });

  testWidgets('宽屏常驻显示目录栏和目录操作入口', (tester) async {
    await pumpHome(tester, const Size(1000, 800));
    expect(find.byType(Drawer), findsNothing);
    expect(find.byType(FolderNavigation), findsOneWidget);
    expect(find.text('疯狂的厨房'), findsOneWidget);
    expect(find.byTooltip('新建根目录'), findsOneWidget);
    expect(find.byTooltip('目录操作'), findsOneWidget);
    expect(find.byTooltip('更多操作'), findsOneWidget);
    expect(find.byType(BookmarkCover), findsOneWidget);
    expect(find.byKey(const Key('bookmark-cover-placeholder')), findsOneWidget);
    expect(find.text('example.com'), findsWidgets);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byKey(const Key('add-bookmark-fab')), findsOneWidget);
    expect(find.text('收藏链接'), findsOneWidget);
    expect(find.byTooltip('刷新'), findsNothing);
  });

  testWidgets('收藏与目录操作菜单使用统一图标菜单项', (tester) async {
    await pumpHome(tester, const Size(1000, 800));

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('移动'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsWidgets);
    expect(find.byIcon(Icons.drive_file_move_outline), findsWidgets);
    expect(find.byIcon(Icons.delete_outline), findsWidgets);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('目录操作').last);
    await tester.pumpAndSettle();
    expect(find.text('添加收藏'), findsOneWidget);
    expect(find.text('新增子目录'), findsOneWidget);
    expect(find.text('移动'), findsOneWidget);
    expect(find.text('重命名'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(find.byIcon(Icons.create_new_folder_outlined), findsWidgets);
  });

  testWidgets('单条与批量移动复用统一目录树选择器', (tester) async {
    await pumpHome(tester, const Size(1000, 800));
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('移动'));
    await tester.pumpAndSettle();
    expect(find.byType(FolderPickerDialog), findsOneWidget);
    expect(find.byType(RadioGroup<String>), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('编辑收藏'));
    await tester.pump();
    expect(find.byKey(const Key('cancel-selection-button')), findsOneWidget);
    expect(find.byKey(const Key('save-selection-button')), findsOneWidget);
    expect(find.byKey(const Key('move-selection-button')), findsOneWidget);
    expect(find.byKey(const Key('delete-selection-button')), findsOneWidget);
    expect(find.byKey(const Key('add-bookmark-fab')), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('move-selection-button')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('move-selection-button')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key('move-selection-button')));
    await tester.pumpAndSettle();
    expect(find.byType(FolderPickerDialog), findsOneWidget);
    expect(find.text('批量移动到'), findsOneWidget);
  });

  testWidgets('目录选择器直接显示创建文件夹图标', (tester) async {
    state.draft = const BookmarkDraft(sourceUrl: 'https://example.com');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: BookmarkForm()),
      ),
    );
    await tester.tap(find.byKey(const Key('folder-picker-trigger')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create-folder-button')), findsOneWidget);
    expect(find.byIcon(Icons.create_new_folder_outlined), findsOneWidget);
    expect(find.byKey(const Key('folder-picker-menu')), findsNothing);
  });

  testWidgets('选择模式取消和保存均退出且右下角仅显示移动删除', (tester) async {
    await pumpHome(tester, const Size(1000, 800));
    await tester.tap(find.byTooltip('编辑收藏'));
    await tester.pump();

    expect(find.text('批量移动'), findsNothing);
    expect(find.text('批量删除'), findsNothing);
    expect(find.text('取消选择'), findsNothing);
    expect(find.byKey(const Key('move-selection-button')), findsOneWidget);
    expect(find.byKey(const Key('delete-selection-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('cancel-selection-button')));
    await tester.pump();
    expect(find.byKey(const Key('add-bookmark-fab')), findsOneWidget);
    expect(find.byKey(const Key('move-selection-button')), findsNothing);

    await tester.tap(find.byTooltip('编辑收藏'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('save-selection-button')));
    await tester.pump();
    expect(find.byKey(const Key('add-bookmark-fab')), findsOneWidget);
    expect(find.byKey(const Key('save-selection-button')), findsNothing);
  });

  testWidgets('目录移动复用统一选择器并排除自身', (tester) async {
    await pumpHome(tester, const Size(1000, 800));
    await tester.tap(find.byTooltip('目录操作').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('移动'));
    await tester.pumpAndSettle();

    expect(find.byType(FolderPickerDialog), findsOneWidget);
    expect(find.text('移动目录到'), findsOneWidget);
    expect(find.byKey(const Key('folder-option-1')), findsNothing);
    expect(find.byKey(const Key('folder-option-root')), findsOneWidget);
  });

  testWidgets('官方扩展 FAB 点击打开草稿，拖动不误触发', (tester) async {
    await pumpHome(tester, const Size(1000, 800));
    final fab = find.byKey(const Key('add-bookmark-fab'));

    await tester.tap(fab);
    await tester.pump();
    expect(state.draft, isNotNull);

    state.closeDraft();
    await tester.pump();
    final before = tester.getTopLeft(fab);
    await tester.drag(fab, const Offset(-180, -120));
    await tester.pumpAndSettle();
    final after = tester.getTopLeft(fab);

    expect(state.draft, isNull);
    expect(after.dx, lessThan(before.dx));
    expect(after.dy, lessThan(before.dy));
    expect(after.dx, greaterThanOrEqualTo(8));
    expect(after.dy, greaterThanOrEqualTo(8));
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
            BookmarkItemCard(item: item, onTap: () {}, onAction: (_) {}),
          ],
        ),
      ),
    );

    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(find.byTooltip('更多操作'), findsOneWidget);
    expect(find.byType(BookmarkCover), findsNWidgets(2));
    expect(find.byType(Card), findsNWidgets(2));
    final cards = tester.widgetList<Card>(find.byType(Card));
    final surface = Theme.of(tester.element(find.byType(Card).first))
        .colorScheme
        .surface;
    expect(cards.every((card) => card.color == surface), isTrue);
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
          ..authenticated = true
          ..folders = const [
            BookmarkFolder(id: '1', name: '家常菜'),
            BookmarkFolder(id: '2', name: '快手汤'),
          ];
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

    // 1. 先弹出目录多选范围确认窗口（默认全选）
    expect(find.text('选择随机目录范围'), findsOneWidget);
    expect(find.byKey(const Key('random-filter-select-all')), findsOneWidget);
    expect(find.byKey(const Key('random-folder-checkbox-1')), findsOneWidget);

    // 点击全不选 -> 勾选目录1 -> 点击“开始随机”
    await tester.tap(find.byKey(const Key('random-filter-select-all')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('random-folder-checkbox-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('random-filter-confirm')));
    await tester.pumpAndSettle();

    expect(state.selectedRandomFolderIds, ['1']);

    // 2. 接着展示随机结果弹窗
    expect(find.text('今天吃什么'), findsOneWidget);
    expect(find.byKey(const Key('random-again-button')), findsOneWidget);
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

  testWidgets('登录页面显示当前应用名称与注册按钮', (tester) async {
    final tokens = MemoryTokenStore();
    state =
        AppState(
            api: ApiClient(
              baseUrl: 'https://api.example/api',
              space: 'cookie',
              tokenStore: tokens,
              httpClient: MockClient((request) async {
                if (request.url.path.endsWith('/auth/register')) {
                  return http.Response(
                    '{"user":{"id":1,"username":"abc"}}',
                    201,
                  );
                }
                if (request.url.path.endsWith('/auth/login')) {
                  return http.Response(
                    '{"token":"Bearer t","user":{"id":1}}',
                    200,
                  );
                }
                if (request.url.path.endsWith('/folders')) {
                  return http.Response('[]', 200);
                }
                return http.Response(
                  '{"items":[],"page":1,"totalPages":1}',
                  200,
                );
              }),
            ),
            tokenStore: tokens,
            preferences: MemoryPreferencesStore(),
          )
          ..initialized = true
          ..authenticated = false;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: LoginPage(appConfig: AppConfig.kitchen)),
      ),
    );

    expect(find.text('疯狂的厨房'), findsOneWidget);
    expect(find.byKey(const Key('login-button')), findsOneWidget);
    expect(find.byKey(const Key('switch-mode-button')), findsOneWidget);
    expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);

    // 切换到注册模式
    await tester.tap(find.byKey(const Key('switch-mode-button')));
    await tester.pumpAndSettle();

    expect(find.text('注册账号'), findsOneWidget);
    expect(find.byKey(const Key('confirm-password-field')), findsOneWidget);
    expect(find.byKey(const Key('submit-register-button')), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '用户名'), 'abc');
    await tester.enterText(find.widgetWithText(TextField, '密码'), '123456');
    await tester.enterText(
      find.byKey(const Key('confirm-password-field')),
      '123456',
    );
    await tester.tap(find.byKey(const Key('submit-register-button')));
    await tester.pumpAndSettle();

    expect(state.authenticated, isTrue);

    // 测试未登录星标模式标题
    final starTokens = MemoryTokenStore();
    final starState =
        AppState(
            api: ApiClient(
              baseUrl: 'https://api.example/api',
              space: 'star',
              tokenStore: starTokens,
              httpClient: MockClient((_) async => http.Response('{}', 200)),
            ),
            tokenStore: starTokens,
            preferences: MemoryPreferencesStore(),
          )
          ..initialized = true
          ..authenticated = false;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: starState,
        child: const MaterialApp(
          key: Key('star-app'),
          home: LoginPage(
            key: Key('star-login-page'),
            appConfig: AppConfig.star,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('鲸界'), findsOneWidget);
    expect(find.byIcon(Icons.water_drop_rounded), findsOneWidget);
  });
}
