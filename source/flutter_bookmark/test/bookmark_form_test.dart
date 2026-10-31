import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:wwjing_bookmark/models/bookmark.dart';
import 'package:wwjing_bookmark/services/api_client.dart';
import 'package:wwjing_bookmark/services/douyin_resolver.dart';
import 'package:wwjing_bookmark/state/app_state.dart';
import 'package:wwjing_bookmark/widgets/bookmark_form.dart';
import 'package:wwjing_bookmark/widgets/folder_picker_dialog.dart';

import 'test_fakes.dart';

void main() {
  testWidgets('目录入口使用官方卡片列表项并支持标准单选', (tester) async {
    final tokens = MemoryTokenStore('Bearer token');
    final state =
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
          ..folders = const [
            BookmarkFolder(id: '1', name: '菜谱'),
            BookmarkFolder(id: '2', name: '快手菜', parentId: '1'),
          ]
          ..draft = const BookmarkDraft(
            sourceUrl: 'https://example.com',
            folderId: '1',
          );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: BookmarkForm()),
      ),
    );

    expect(find.byKey(const Key('folder-picker-trigger')), findsOneWidget);
    expect(find.widgetWithText(ListTile, '收藏夹'), findsOneWidget);
    expect(find.text('菜谱'), findsOneWidget);

    await tester.tap(find.byKey(const Key('folder-picker-trigger')));
    await tester.pumpAndSettle();
    expect(find.byType(RadioGroup<String>), findsNothing);
    expect(find.byType(RadioListTile<String>), findsNothing);

    await tester.tap(find.byKey(const Key('folder-option-2')));
    await tester.pump();
    final nested = tester.widget<ListTile>(
      find.byKey(const Key('folder-option-2')),
    );
    expect(nested.selected, isTrue);
    expect(
      nested.selectedTileColor,
      Theme.of(tester.element(find.byKey(const Key('folder-option-2'))))
          .colorScheme
          .primary
          .withValues(alpha: 0.08),
    );
    expect(nested.selectedColor, isNotNull);
    final selectedTiles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .where((tile) => tile.selected);
    expect(selectedTiles.length, 1);
    await tester.tap(find.widgetWithText(FilledButton, '选择'));
    await tester.pumpAndSettle();
    expect(find.text('快手菜'), findsOneWidget);

    await tester.tap(find.byKey(const Key('folder-picker-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('folder-option-root')));
    await tester.tap(find.widgetWithText(FilledButton, '选择'));
    await tester.pumpAndSettle();
    expect(find.text('未分类'), findsOneWidget);
  });

  testWidgets('在当前单选目录下创建子目录并写回选择', (tester) async {
    final tokens = MemoryTokenStore('Bearer token');
    String? receivedParentId;
    final state =
        AppState(
            api: ApiClient(
              baseUrl: 'https://api.example/api',
              space: 'cookie',
              tokenStore: tokens,
              httpClient: MockClient((request) async {
                if (request.method == 'POST' &&
                    request.url.path.endsWith('/folders')) {
                  receivedParentId =
                      (jsonDecode(request.body) as Map)['parentId'] as String?;
                  return http.Response.bytes(
                    utf8.encode(
                      '{"folder":{"id":"3","name":"晚餐","parentId":"1"}}',
                    ),
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8',
                    },
                  );
                }
                if (request.url.path.endsWith('/folders')) {
                  return http.Response.bytes(
                    utf8.encode(
                      '[{"id":"1","name":"菜谱"},{"id":"3","name":"晚餐","parentId":"1"}]',
                    ),
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8',
                    },
                  );
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
          ..authenticated = true
          ..folders = const [BookmarkFolder(id: '1', name: '菜谱')]
          ..draft = const BookmarkDraft(
            sourceUrl: 'https://example.com',
            folderId: '1',
          );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: BookmarkForm()),
      ),
    );

    await tester.tap(find.byKey(const Key('folder-picker-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-folder-button')));
    await tester.pump();
    expect(find.byKey(const Key('inline-folder-editor')), findsOneWidget);
    expect(find.byType(FolderPickerDialog), findsOneWidget);
    final cancelButton = tester.widget<IconButton>(
      find.byKey(const Key('cancel-inline-folder-button')),
    );
    final confirmButton = tester.widget<IconButton>(
      find.byKey(const Key('confirm-inline-folder-button')),
    );
    expect(cancelButton.constraints?.maxWidth, 32);
    expect(confirmButton.constraints?.maxWidth, 32);
    expect(confirmButton.color, Colors.green);
    expect(confirmButton.style?.backgroundColor, isNull);
    await tester.enterText(
      find.byKey(const Key('inline-folder-name-field')),
      '晚餐',
    );
    await tester.tap(find.byKey(const Key('confirm-inline-folder-button')));
    await tester.pumpAndSettle();

    expect(receivedParentId, '1');
    expect(find.byType(FolderPickerDialog), findsOneWidget);
    expect(find.byKey(const Key('inline-folder-editor')), findsNothing);
    final createdTile = tester.widget<ListTile>(
      find.byKey(const Key('folder-option-3')),
    );
    expect(createdTile.selected, isTrue);
    expect(find.text('晚餐'), findsOneWidget);
  });

  testWidgets('可取消目录树内联新增', (tester) async {
    final tokens = MemoryTokenStore('Bearer token');
    final state =
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
          ..draft = const BookmarkDraft(sourceUrl: 'https://example.com');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: BookmarkForm()),
      ),
    );

    await tester.tap(find.byKey(const Key('folder-picker-trigger')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('create-folder-button')));
    await tester.pump();
    expect(find.byKey(const Key('inline-folder-editor')), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancel-inline-folder-button')));
    await tester.pump();
    expect(find.byKey(const Key('inline-folder-editor')), findsNothing);
  });

  testWidgets('保存小红书短链前解析并持久化完整 finalUrl', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final tokens = MemoryTokenStore('Bearer token');
    const finalUrl =
        'https://www.xiaohongshu.com/discovery/item/abc123?xsec_token=token&share_id=share';
    String? savedUrl;
    final state =
        AppState(
            api: ApiClient(
              baseUrl: 'https://api.example/api',
              space: 'cookie',
              tokenStore: tokens,
              httpClient: MockClient((request) async {
                if (request.url.path.endsWith('/metadata')) {
                  return http.Response.bytes(
                    utf8.encode(
                      jsonEncode({
                        'metadata': {'finalUrl': finalUrl},
                      }),
                    ),
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8',
                    },
                  );
                }
                if (request.method == 'POST' &&
                    request.url.path.endsWith('/items')) {
                  savedUrl =
                      (jsonDecode(request.body) as Map)['sourceUrl'] as String;
                  return http.Response.bytes(
                    utf8.encode(
                      jsonEncode({
                        'item': {'id': '1', 'sourceUrl': savedUrl},
                      }),
                    ),
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8',
                    },
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
          ..authenticated = true
          ..draft = const BookmarkDraft(
            sourceUrl: 'https://xhslink.cn/o/short',
          );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: BookmarkForm()),
      ),
    );

    final saveButton = find.widgetWithText(FilledButton, '保存');
    await tester.scrollUntilVisible(
      saveButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(savedUrl, finalUrl);
  });

  testWidgets('小红书短链解析失败时保留表单并阻止保存', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final tokens = MemoryTokenStore('Bearer token');
    var createCalls = 0;
    final state =
        AppState(
            api: ApiClient(
              baseUrl: 'https://api.example/api',
              space: 'cookie',
              tokenStore: tokens,
              httpClient: MockClient((request) async {
                if (request.url.path.endsWith('/metadata')) {
                  return http.Response.bytes(
                    utf8.encode(
                      jsonEncode({
                        'metadata': {
                          'finalUrl': 'https://xhslink.cn/o/still-short',
                        },
                      }),
                    ),
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8',
                    },
                  );
                }
                createCalls++;
                return http.Response('{}', 200);
              }),
            ),
            tokenStore: tokens,
            preferences: MemoryPreferencesStore(),
          )
          ..initialized = true
          ..authenticated = true
          ..draft = const BookmarkDraft(
            sourceUrl: 'https://xhslink.cn/o/short',
          );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: BookmarkForm()),
      ),
    );

    final saveButton = find.widgetWithText(FilledButton, '保存');
    await tester.scrollUntilVisible(
      saveButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(createCalls, 0);
    expect(find.text('小红书短链解析失败，请稍后重试'), findsOneWidget);
    expect(find.text('https://xhslink.cn/o/short'), findsOneWidget);
  });

  testWidgets('点击粘贴后自动异步触发元数据与封面识别', (tester) async {
    final tokens = MemoryTokenStore('Bearer token');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') {
          return {'text': 'https://example.com/pasted'};
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    var metadataRequested = false;
    final state =
        AppState(
            api: ApiClient(
              baseUrl: 'https://api.example/api',
              space: 'cookie',
              tokenStore: tokens,
              httpClient: MockClient((request) async {
                if (request.url.path.endsWith('/metadata')) {
                  metadataRequested = true;
                  return http.Response.bytes(
                    utf8.encode(
                      jsonEncode({
                        'metadata': {
                          'finalUrl': 'https://example.com/pasted',
                          'title': '自动识别文章',
                          'coverUrl': 'https://example.com/auto-cover.png',
                        },
                      }),
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
          ..draft = const BookmarkDraft(sourceUrl: '');

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: BookmarkForm()),
      ),
    );

    await tester.tap(find.widgetWithText(TextButton, '粘贴'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(metadataRequested, isTrue);
    expect(find.widgetWithText(TextField, '自动识别文章'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'https://example.com/auto-cover.png'),
      findsOneWidget,
    );
  });

  test('DouyinResolver 格式检测与解析回退', () async {
    expect(DouyinResolver.isDouyinUrl('https://v.douyin.com/test'), isTrue);
    expect(DouyinResolver.isDouyinUrl('https://www.iesdouyin.com/share/video/123'), isTrue);
    expect(DouyinResolver.isDouyinUrl('https://www.bilibili.com/video/BV123'), isFalse);

    final mockClient = MockClient((request) async {
      return http.Response.bytes(
        utf8.encode(jsonEncode({
          'code': 200,
          'data': {
            'title': '测试抖音作品',
            'desc': '这是描述',
            'cover': 'http://p3-sign.douyinpic.com/test.jpg'
          }
        })),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final resolver = DouyinResolver(client: mockClient);
    final res = await resolver.resolve('https://v.douyin.com/test');
    expect(res?.title, '测试抖音作品');
    expect(res?.coverUrl, 'https://p3-sign.douyinpic.com/test.jpg');
  });
}
