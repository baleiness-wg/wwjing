import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wwjing_kitchen/models/bookmark.dart';
import 'package:wwjing_kitchen/services/api_client.dart';
import 'package:wwjing_kitchen/state/app_state.dart';

import 'test_fakes.dart';

void main() {
  test('解析收藏封面并保留可空值', () {
    final withCover = BookmarkItem.fromJson({
      'id': 1,
      'sourceUrl': 'https://example.com/article',
      'coverUrl': 'https://cdn.example.com/cover.jpg',
    });
    final withoutCover = BookmarkItem.fromJson({
      'id': 2,
      'source_url': 'https://example.com/other',
      'cover_url': null,
    });

    expect(withCover.coverUrl, 'https://cdn.example.com/cover.jpg');
    expect(withoutCover.coverUrl, isNull);
  });

  test('元数据接口发送 sourceUrl 并解析响应', () async {
    final tokens = MemoryTokenStore('Bearer token');
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/bookmarks/metadata');
      expect(jsonDecode(request.body), {
        'sourceUrl': 'https://example.com/start',
      });
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'metadata': {
              'finalUrl': 'https://example.com/final',
              'title': '示例文章',
              'description': '文章摘要',
              'coverUrl': 'https://example.com/cover.jpg',
            },
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = ApiClient(
      baseUrl: 'https://api.example/api',
      tokenStore: tokens,
      httpClient: client,
    );

    final metadata = await api.getBookmarkMetadata('https://example.com/start');

    expect(metadata.finalUrl, 'https://example.com/final');
    expect(metadata.title, '示例文章');
    expect(metadata.description, '文章摘要');
    expect(metadata.coverUrl, 'https://example.com/cover.jpg');
  });

  test('登录令牌只写入安全存储且 Bearer 请求头格式正确', () async {
    final tokens = MemoryTokenStore();
    final preferences = MemoryPreferencesStore();
    final seen = <http.Request>[];
    final client = MockClient((request) async {
      seen.add(request);
      if (request.url.path.endsWith('/auth/login')) {
        expect(jsonDecode(request.body), {
          'username': 'tester',
          'password': 'secret',
        });
        return http.Response(
          jsonEncode({
            'token': 'Bearer jwt-value',
            'user': {'id': 1},
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/folders')) {
        return http.Response('[]', 200);
      }
      return http.Response(
        jsonEncode({'items': [], 'page': 1, 'totalPages': 1}),
        200,
      );
    });
    final api = ApiClient(
      baseUrl: 'https://api.example/api',
      tokenStore: tokens,
      httpClient: client,
    );
    final state = AppState(
      api: api,
      tokenStore: tokens,
      preferences: preferences,
    );

    await state.login('tester', 'secret');

    expect(tokens.value, 'Bearer jwt-value');
    expect(preferences.recent, isEmpty);
    expect(
      seen
          .where((request) => request.url.path.endsWith('/folders'))
          .single
          .headers['Authorization'],
      'Bearer jwt-value',
    );
  });

  test('401 清除令牌但保留待收藏草稿供重新登录恢复', () async {
    final tokens = MemoryTokenStore('Bearer expired');
    final preferences = MemoryPreferencesStore();
    var unauthorizedCalled = false;
    late final AppState state;
    final api = ApiClient(
      baseUrl: 'https://api.example/api',
      tokenStore: tokens,
      httpClient: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(jsonEncode({'message': '登录已失效'})),
          401,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
      onUnauthorized: () async {
        unauthorizedCalled = true;
        await state.handleUnauthorized();
      },
    );
    state = AppState(api: api, tokenStore: tokens, preferences: preferences);
    state.initialized = true;
    state.authenticated = true;
    state.draft = const BookmarkDraft(
      sourceUrl: 'https://example.com',
      description: '分享原文',
    );

    expect(state.authenticated, isTrue);
    await expectLater(api.getFolders(), throwsA(isA<ApiException>()));

    expect(unauthorizedCalled, isTrue);
    expect(state.authenticated, isFalse);
    expect(tokens.value, isNull);
    expect(state.draft?.sourceUrl, 'https://example.com');
  });

  test('解析后端嵌套错误码并根据 total 计算总页数', () async {
    final tokens = MemoryTokenStore('Bearer token');
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode({'items': [], 'total': 41, 'page': 2, 'pageSize': 20}),
          200,
        );
      }
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'error': {
              'code': 'DUPLICATE_BOOKMARK',
              'message': '该链接已收藏',
              'duplicate': {'id': '9'},
            },
          }),
        ),
        409,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = ApiClient(
      baseUrl: 'https://api.example/api',
      tokenStore: tokens,
      httpClient: client,
    );

    final page = await api.getItems(page: 2);
    expect(page.totalPages, 3);

    await expectLater(
      api.createItem(const BookmarkDraft(sourceUrl: 'https://example.com')),
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', 'DUPLICATE_BOOKMARK')
            .having((error) => error.message, 'message', '该链接已收藏'),
      ),
    );
  });
}
