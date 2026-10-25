import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/bookmark.dart';
import 'token_store.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code, this.data});
  final String message;
  final int? statusCode;
  final String? code;
  final Object? data;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.tokenStore,
    http.Client? httpClient,
    this.onUnauthorized,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final TokenStore tokenStore;
  final http.Client _http;
  final Future<void> Function()? onUnauthorized;

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await _http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    return _decode(response) as Map<String, dynamic>;
  }

  Future<List<BookmarkFolder>> getFolders() async {
    final data = await _request('GET', '/bookmarks/folders');
    final raw = data is List
        ? data
        : (data as Map<String, dynamic>)['folders'] as List? ?? const [];
    return raw
        .map((value) => BookmarkFolder.fromJson(value as Map<String, dynamic>))
        .toList();
  }

  Future<BookmarkFolder> createFolder({
    required String name,
    String? parentId,
  }) async {
    final data = await _request(
      'POST',
      '/bookmarks/folders',
      body: {'name': name, 'parentId': parentId},
    );
    return BookmarkFolder.fromJson(_unwrap(data, 'folder'));
  }

  Future<void> updateFolder(String id, Map<String, Object?> changes) async {
    await _request('PATCH', '/bookmarks/folders/$id', body: changes);
  }

  Future<void> deleteFolder(String id) async {
    await _request('DELETE', '/bookmarks/folders/$id');
  }

  Future<({List<BookmarkItem> items, int page, int totalPages})> getItems({
    String? folderId,
    bool uncategorized = false,
    String query = '',
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, String>{'page': '$page', 'pageSize': '$pageSize'};
    if (folderId != null) params['folderId'] = folderId;
    if (uncategorized) params['uncategorized'] = 'true';
    if (query.trim().isNotEmpty) params['query'] = query.trim();
    final data = await _request('GET', '/bookmarks/items', query: params);
    final map = data is Map<String, dynamic>
        ? data
        : <String, dynamic>{'items': data};
    final raw = map['items'] as List? ?? map['data'] as List? ?? const [];
    final pagination = map['pagination'] as Map<String, dynamic>? ?? map;
    final totalPages =
        (pagination['totalPages'] as num?)?.toInt() ??
        (((pagination['total'] as num?)?.toInt() ?? 0) / pageSize).ceil();
    return (
      items: raw
          .map((value) => BookmarkItem.fromJson(value as Map<String, dynamic>))
          .toList(),
      page: (pagination['page'] as num?)?.toInt() ?? page,
      totalPages: totalPages < 1 ? 1 : totalPages,
    );
  }

  Future<BookmarkItem> createItem(
    BookmarkDraft draft, {
    bool allowDuplicate = false,
  }) async {
    final data = await _request(
      'POST',
      '/bookmarks/items',
      body: {
        'sourceUrl': draft.sourceUrl,
        'title': draft.title.trim().isEmpty ? null : draft.title.trim(),
        'description': draft.description.trim().isEmpty
            ? null
            : draft.description.trim(),
        'folderId': draft.folderId,
        'coverUrl': draft.coverUrl.trim().isEmpty
            ? null
            : draft.coverUrl.trim(),
        'allowDuplicate': allowDuplicate,
      },
    );
    return BookmarkItem.fromJson(_unwrap(data, 'item'));
  }

  Future<BookmarkMetadata> getBookmarkMetadata(String sourceUrl) async {
    final data = await _request(
      'POST',
      '/bookmarks/metadata',
      body: {'sourceUrl': sourceUrl},
    );
    return BookmarkMetadata.fromJson(_unwrap(data, 'metadata'));
  }

  Future<void> updateItem(String id, Map<String, Object?> changes) async {
    await _request('PATCH', '/bookmarks/items/$id', body: changes);
  }

  Future<void> deleteItem(String id) async {
    await _request('DELETE', '/bookmarks/items/$id');
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
  }) async {
    final token = await tokenStore.read();
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers.addAll({
        'Content-Type': 'application/json',
        if (token != null)
          'Authorization': token.startsWith('Bearer ')
              ? token
              : 'Bearer $token',
      });
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(await _http.send(request));
    if (response.statusCode == 401) {
      await tokenStore.clear();
      await onUnauthorized?.call();
    }
    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    final dynamic data = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final map = data is Map<String, dynamic>
          ? data
          : const <String, dynamic>{};
      final details = map['error'] is Map<String, dynamic>
          ? map['error'] as Map<String, dynamic>
          : map;
      throw ApiException(
        details['message'] as String? ?? '请求失败（${response.statusCode}）',
        statusCode: response.statusCode,
        code: details['code'] as String?,
        data: details,
      );
    }
    return data;
  }

  Map<String, dynamic> _unwrap(dynamic data, String key) {
    final map = data as Map<String, dynamic>;
    return (map[key] as Map<String, dynamic>?) ?? map;
  }
}
