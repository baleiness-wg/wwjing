import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import '../viewmodels/bookmark.dart';
import '../utils/token_store.dart';

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
    required this.space,
    required this.tokenStore,
    http.Client? httpClient,
    this.onUnauthorized,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String space;
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

  Future<Map<String, dynamic>> register(
    String username,
    String password,
  ) async {
    final response = await _http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    return _decode(response) as Map<String, dynamic>;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _request(
      'POST',
      '/auth/change-password',
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
    );
  }

  Future<String> getProfileDescription() async {
    final data =
        await _request('GET', '/auth/user-profile') as Map<String, dynamic>;
    final user = data['user'] as Map<String, dynamic>?;
    return user?['profileDescription'] as String? ?? '';
  }

  Future<void> updateProfileDescription(String description) async {
    await _request(
      'PATCH',
      '/auth/user-profile',
      body: {'description': description},
    );
  }

  Future<List<BookmarkFolder>> getFolders() async {
    final data = await _request(
      'GET',
      '/bookmarks/folders',
      query: {'space': space},
    );
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
      body: {'name': name, 'parentId': parentId, 'space': space},
    );
    return BookmarkFolder.fromJson(_unwrap(data, 'folder'));
  }

  Future<void> updateFolder(String id, Map<String, Object?> changes) async {
    await _request(
      'PATCH',
      '/bookmarks/folders/$id',
      body: {...changes, 'space': space},
    );
  }

  Future<void> pinFolder(String id, bool pinned) =>
      updateFolder(id, {'pinned': pinned});

  Future<void> shareFolder(String id, String username) async {
    await _request(
      'POST',
      '/bookmarks/folders/$id/shares',
      body: {'username': username, 'space': space},
    );
  }

  Future<List<Map<String, dynamic>>> getFolderShares(String id) async {
    final data = await _request(
      'GET',
      '/bookmarks/folders/$id/shares',
      query: {'space': space},
    );
    final shares = (data as Map<String, dynamic>)['shares'];
    return (shares as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<void> removeFolderShare(String id, String userId) async {
    await _request(
      'DELETE',
      '/bookmarks/folders/$id/shares/$userId',
      query: {'space': space},
    );
  }

  Future<void> deleteFolder(String id) async {
    await _request('DELETE', '/bookmarks/folders/$id?space=$space');
  }

  Future<List<InspirationEntry>> getInspirations() async {
    final result = await getItems(
      itemType: 'inspiration',
      excludeCompleted: true,
      pageSize: 100,
    );
    return result.items.map(InspirationEntry.fromBookmarkItem).toList();
  }

  Future<InspirationEntry> createInspiration({
    required String content,
    String? title,
    String? folderId,
  }) async {
    final data = await _request(
      'POST',
      '/bookmarks/items',
      body: {
        'itemType': 'inspiration',
        'content': content,
        'description': content,
        'title': title,
        'folderId': folderId,
        'space': space,
      },
    ) as Map<String, dynamic>;
    return InspirationEntry.fromBookmarkItem(
      BookmarkItem.fromJson(data['item'] as Map<String, dynamic>),
    );
  }

  Future<InspirationEntry> updateInspiration(
    String id, {
    required String content,
    String? title,
    String? folderId,
  }) async {
    final data = await _request(
      'PATCH',
      '/bookmarks/items/$id',
      body: {
        'itemType': 'inspiration',
        'content': content,
        'description': content,
        'title': title,
        'folderId': folderId,
        'space': space,
      },
    ) as Map<String, dynamic>;
    return InspirationEntry.fromBookmarkItem(
      BookmarkItem.fromJson(data['item'] as Map<String, dynamic>),
    );
  }

  Future<void> deleteInspiration(String id) async {
    await deleteItem(id);
  }

  Future<void> completeInspiration(String id) async {
    await updateItem(id, {
      'metadata': {'completed': true},
    });
  }

  Future<({List<BookmarkItem> items, int page, int totalPages})> getItems({
    String? folderId,
    bool includeDescendants = false,
    bool uncategorized = false,
    String query = '',
    String? platform,
    String? itemType,
    bool excludeCompleted = false,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'pageSize': '$pageSize',
      'space': space,
    };
    if (folderId != null) params['folderId'] = folderId;
    if (includeDescendants) params['includeDescendants'] = 'true';
    if (uncategorized) params['uncategorized'] = 'true';
    if (query.trim().isNotEmpty) params['query'] = query.trim();
    if (platform != null && platform != 'all') params['platform'] = platform;
    if (itemType != null) params['itemType'] = itemType;
    if (excludeCompleted) params['excludeCompleted'] = 'true';
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

  Future<List<BookmarkItem>> getAllItems() async {
    final all = <BookmarkItem>[];
    var page = 1;
    var totalPages = 1;
    do {
      final result = await getItems(page: page, pageSize: 100);
      all.addAll(result.items);
      totalPages = result.totalPages;
      page++;
    } while (page <= totalPages);
    return all;
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
        'folderIds': draft.folderIds,
        'space': space,
        'images': draft.images,
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

  Future<BookmarkItem?> getRandomItem({Iterable<String>? folderIds}) async {
    final query = <String, String>{'space': space};
    if (folderIds != null && folderIds.isNotEmpty) {
      query['folderIds'] = folderIds.join(',');
    }
    final data = await _request('GET', '/bookmarks/random', query: query);
    final item = (data as Map<String, dynamic>)['item'];
    return item == null
        ? null
        : BookmarkItem.fromJson(item as Map<String, dynamic>);
  }

  Future<({String answer, bool truncated})> chatWithDirectory({
    required Map<String, Object?> context,
    required String message,
    List<Map<String, String>> history = const [],
  }) async {
    final data = await _request(
      'POST',
      '/ai/chat',
      body: {'context': context, 'message': message, 'history': history},
    ) as Map<String, dynamic>;
    return (
      answer: data['answer'] as String? ?? '',
      truncated: data['truncated'] as bool? ?? false,
    );
  }

  Future<void> updateItem(String id, Map<String, Object?> changes) async {
    await _request(
      'PATCH',
      '/bookmarks/items/$id',
      body: {...changes, 'space': space},
    );
  }

  Future<BookmarkItem> getItem(String id) async {
    final data = await _request(
      'GET',
      '/bookmarks/items/$id',
      query: {'space': space},
    ) as Map<String, dynamic>;
    return BookmarkItem.fromJson(data['item'] as Map<String, dynamic>);
  }

  Future<void> deleteItem(String id) async {
    await _request('DELETE', '/bookmarks/items/$id?space=$space');
  }

  Future<List<String>> uploadItemImage(String id, String path) async {
    debugPrint(
      '[ApiClient] POST /bookmarks/items/$id/images file=$path space=$space',
    );
    final token = await tokenStore.read();
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/bookmarks/items/$id/images'),
          )
          ..headers['Authorization'] = token == null
              ? ''
              : (token.startsWith('Bearer ') ? token : 'Bearer $token')
          ..fields['space'] = space
          ..files.add(await http.MultipartFile.fromPath('image', path));
    final response = await http.Response.fromStream(await _http.send(request));
    debugPrint(
      '[ApiClient] image upload response status=${response.statusCode} bodyLength=${response.body.length}',
    );
    final data = _decode(response) as Map<String, dynamic>;
    return (data['images'] as List? ?? const []).whereType<String>().toList();
  }

  Future<void> pinItem(String id, String folderId, bool pinned) async {
    await _request(
      'PATCH',
      '/bookmarks/items/$id/pin',
      body: {'folderId': folderId, 'pinned': pinned, 'space': space},
    );
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
        data: details['data'] ?? details['duplicate'] ?? details,
      );
    }
    return data;
  }

  Map<String, dynamic> _unwrap(dynamic data, String key) {
    final map = data as Map<String, dynamic>;
    return (map[key] as Map<String, dynamic>?) ?? map;
  }
}
