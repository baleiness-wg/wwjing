import 'package:flutter/foundation.dart';

import '../models/bookmark.dart';
import '../models/shared_link.dart';
import '../services/api_client.dart';
import '../services/preferences_store.dart';
import '../services/token_store.dart';

enum BookmarkView { all, uncategorized, folder }

class AppState extends ChangeNotifier {
  AppState({
    required this.api,
    required this.tokenStore,
    required this.preferences,
  });

  final ApiClient api;
  final TokenStore tokenStore;
  final PreferencesStore preferences;

  bool initialized = false;
  bool authenticated = false;
  bool busy = false;
  String? error;
  String? errorCode;
  Object? errorData;
  String? metadataMessage;
  BookmarkDraft? draft;
  String? editingItemId;
  List<BookmarkFolder> folders = [];
  List<BookmarkItem> items = [];
  List<String> recentFolderIds = [];
  BookmarkView view = BookmarkView.all;
  String? selectedFolderId;
  String query = '';
  int page = 1;
  int totalPages = 1;

  List<FolderNode> get folderTree => buildFolderTree(folders);

  Future<void> initialize() async {
    recentFolderIds = await preferences.recentFolders();
    authenticated = await tokenStore.read() != null;
    initialized = true;
    notifyListeners();
    if (authenticated) await refresh();
  }

  Future<void> login(String username, String password) async {
    await _run(() async {
      final result = await api.login(username, password);
      final token = result['token'] as String?;
      if (token == null || token.isEmpty) throw const ApiException('登录响应缺少令牌');
      await tokenStore.write(token);
      authenticated = true;
      await refresh();
    });
  }

  Future<void> logout({bool expired = false}) async {
    await tokenStore.clear();
    authenticated = false;
    folders = [];
    items = [];
    if (!expired) draft = null;
    notifyListeners();
  }

  Future<void> handleUnauthorized() => logout(expired: true);

  Future<void> refresh({bool resetPage = false}) async {
    if (!authenticated) return;
    if (resetPage) page = 1;
    await _run(() async {
      folders = await api.getFolders();
      final result = await api.getItems(
        folderId: view == BookmarkView.folder ? selectedFolderId : null,
        includeDescendants: view == BookmarkView.folder,
        uncategorized: view == BookmarkView.uncategorized,
        query: query,
        page: page,
      );
      items = result.items;
      page = result.page;
      totalPages = result.totalPages;
    });
  }

  Future<void> selectView(BookmarkView nextView, [String? folderId]) async {
    view = nextView;
    selectedFolderId = folderId;
    await refresh(resetPage: true);
  }

  Future<void> search(String value) async {
    query = value;
    await refresh(resetPage: true);
  }

  Future<void> goToPage(int value) async {
    page = value.clamp(1, totalPages);
    await refresh();
  }

  void openSharedText(String text) {
    final shared = extractSharedLink(text);
    if (shared == null) {
      error = '未识别到 HTTP/HTTPS 链接';
    } else {
      draft = BookmarkDraft(
        sourceUrl: shared.url,
        title: shared.title,
        description: shared.originalText,
        fetchMetadataOnOpen: true,
      );
      editingItemId = null;
      error = null;
    }
    notifyListeners();
  }

  void openDraft([BookmarkItem? item]) {
    editingItemId = item?.id;
    draft = item == null
        ? const BookmarkDraft(sourceUrl: '')
        : BookmarkDraft(
            sourceUrl: item.sourceUrl,
            title: item.title ?? '',
            description: item.description ?? '',
            folderId: item.folderId,
            coverUrl: item.coverUrl ?? '',
          );
    notifyListeners();
  }

  void openDraftInFolder(String folderId) {
    editingItemId = null;
    draft = BookmarkDraft(sourceUrl: '', folderId: folderId);
    notifyListeners();
  }

  void closeDraft() {
    draft = null;
    editingItemId = null;
    notifyListeners();
  }

  Future<BookmarkMetadata?> fetchBookmarkMetadata(String sourceUrl) async {
    metadataMessage = null;
    notifyListeners();
    try {
      return await api.getBookmarkMetadata(sourceUrl);
    } on ApiException catch (exception) {
      metadataMessage = '封面识别失败：${exception.message}';
    } catch (_) {
      metadataMessage = '封面识别失败，请检查连接后重试';
    }
    notifyListeners();
    return null;
  }

  Future<bool> saveDraft(
    BookmarkDraft value, {
    bool allowDuplicate = false,
  }) async {
    draft = value;
    var saved = false;
    await _run(() async {
      if (editingItemId == null) {
        await api.createItem(value, allowDuplicate: allowDuplicate);
      } else {
        await api.updateItem(editingItemId!, {
          'sourceUrl': value.sourceUrl,
          'title': value.title.trim().isEmpty ? null : value.title.trim(),
          'description': value.description.trim().isEmpty
              ? null
              : value.description.trim(),
          'folderId': value.folderId,
          'coverUrl': value.coverUrl.trim().isEmpty
              ? null
              : value.coverUrl.trim(),
        });
      }
      if (value.folderId != null) {
        await preferences.rememberFolder(value.folderId!);
        recentFolderIds = await preferences.recentFolders();
      }
      draft = null;
      editingItemId = null;
      saved = true;
      await refresh(resetPage: true);
    });
    return saved;
  }

  Future<void> deleteItem(String id) async {
    await _run(() async {
      await api.deleteItem(id);
      await refresh();
    });
  }

  Future<void> moveItem(String id, String? folderId) async {
    await _run(() async {
      await api.updateItem(id, {'folderId': folderId});
      await refresh();
    });
  }

  Future<void> moveItems(Iterable<String> ids, String? folderId) async {
    await _run(() async {
      for (final id in ids) {
        await api.updateItem(id, {'folderId': folderId});
      }
      await refresh(resetPage: true);
    });
  }

  Future<void> deleteItems(Iterable<String> ids) async {
    await _run(() async {
      for (final id in ids) {
        await api.deleteItem(id);
      }
      await refresh(resetPage: true);
    });
  }

  Future<bool> overwriteItem(String id, BookmarkDraft value) async {
    var updated = false;
    await _run(() async {
      await api.updateItem(id, {
        'sourceUrl': value.sourceUrl,
        'title': value.title.trim().isEmpty ? null : value.title.trim(),
        'description': value.description.trim().isEmpty ? null : value.description.trim(),
        'folderId': value.folderId,
        'coverUrl': value.coverUrl.trim().isEmpty ? null : value.coverUrl.trim(),
      });
      updated = true;
      await refresh(resetPage: true);
    });
    return updated;
  }

  Future<void> openFolder(String? folderId) async {
    if (folderId == null) {
      await selectView(BookmarkView.uncategorized);
    } else {
      await selectView(BookmarkView.folder, folderId);
    }
  }

  Future<BookmarkFolder?> createFolder(String name, String? parentId) async {
    BookmarkFolder? created;
    await _run(() async {
      created = await api.createFolder(name: name, parentId: parentId);
      await refresh();
    });
    return created;
  }

  Future<void> renameFolder(BookmarkFolder folder, String name) async {
    await _run(() async {
      await api.updateFolder(folder.id, {'name': name});
      await refresh();
    });
  }

  Future<void> moveFolder(BookmarkFolder folder, String? parentId) async {
    await _run(() async {
      await api.updateFolder(folder.id, {'parentId': parentId});
      await refresh();
    });
  }

  Future<void> reorderFolder(BookmarkFolder folder, int delta) async {
    await _run(() async {
      await api.updateFolder(folder.id, {
        'position': (folder.position + delta).clamp(0, 1 << 30),
      });
      await refresh();
    });
  }

  Future<void> deleteFolder(BookmarkFolder folder) async {
    await _run(() async {
      await api.deleteFolder(folder.id);
      if (selectedFolderId == folder.id) {
        view = BookmarkView.all;
        selectedFolderId = null;
      }
      await refresh();
    });
  }

  Future<void> _run(Future<void> Function() operation) async {
    busy = true;
    error = null;
    errorCode = null;
    errorData = null;
    notifyListeners();
    try {
      await operation();
    } on ApiException catch (exception) {
      error = exception.message;
      errorCode = exception.code;
      errorData = exception.data;
    } catch (_) {
      error = '网络请求失败，请检查连接后重试';
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
