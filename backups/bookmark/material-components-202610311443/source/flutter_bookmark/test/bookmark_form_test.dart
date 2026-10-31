import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:wwjing_bookmark/models/bookmark.dart';
import 'package:wwjing_bookmark/services/api_client.dart';
import 'package:wwjing_bookmark/state/app_state.dart';
import 'package:wwjing_bookmark/widgets/bookmark_form.dart';

import 'test_fakes.dart';

void main() {
  testWidgets('保存小红书短链前解析并持久化完整 finalUrl', (tester) async {
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

    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(savedUrl, finalUrl);
  });

  testWidgets('小红书短链解析失败时保留表单并阻止保存', (tester) async {
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

    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(createCalls, 0);
    expect(find.text('小红书短链解析失败，请稍后重试'), findsOneWidget);
    expect(find.text('https://xhslink.cn/o/short'), findsOneWidget);
  });
}
