import 'package:shared_preferences/shared_preferences.dart';

abstract interface class PreferencesStore {
  Future<List<String>> recentFolders();
  Future<void> rememberFolder(String id);
  Future<String?> handledClipboardUrl();
  Future<void> setHandledClipboardUrl(String url);
  Future<List<String>?> selectedRandomFolderIds();
  Future<void> setSelectedRandomFolderIds(List<String>? folderIds);
  Future<List<String>> recommendations();
  Future<void> saveRecommendation(String value);
  Future<List<String>> recommendationItemIds();
  Future<void> saveRecommendationItemId(String value);
}

class SharedPreferencesStore implements PreferencesStore {
  static const _recentKey = 'recent_folder_ids';
  static const _clipboardKey = 'handled_clipboard_url';
  static const _randomFoldersKey = 'selected_random_folder_ids';
  static const _recommendationsKey = 'home_recommendations';
  static const _recommendationItemIdsKey = 'home_recommendation_item_ids';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<List<String>> recentFolders() async =>
      (await _prefs).getStringList(_recentKey) ?? const [];

  @override
  Future<void> rememberFolder(String id) async {
    final prefs = await _prefs;
    final ids = [
      id,
      ...(prefs.getStringList(_recentKey) ?? const <String>[]).where(
        (value) => value != id,
      ),
    ].take(5);
    await prefs.setStringList(_recentKey, ids.toList());
  }

  @override
  Future<String?> handledClipboardUrl() async =>
      (await _prefs).getString(_clipboardKey);

  @override
  Future<void> setHandledClipboardUrl(String url) async =>
      (await _prefs).setString(_clipboardKey, url);

  @override
  Future<List<String>?> selectedRandomFolderIds() async {
    final prefs = await _prefs;
    return prefs.getStringList(_randomFoldersKey);
  }

  @override
  Future<void> setSelectedRandomFolderIds(List<String>? folderIds) async {
    final prefs = await _prefs;
    if (folderIds == null) {
      await prefs.remove(_randomFoldersKey);
    } else {
      await prefs.setStringList(_randomFoldersKey, folderIds);
    }
  }

  @override
  Future<List<String>> recommendations() async =>
      (await _prefs).getStringList(_recommendationsKey) ?? const [];

  @override
  Future<void> saveRecommendation(String value) async {
    final prefs = await _prefs;
    final values = [
      value,
      ...(prefs.getStringList(_recommendationsKey) ?? const <String>[]),
    ].take(10).toList();
    await prefs.setStringList(_recommendationsKey, values);
  }

  @override
  Future<List<String>> recommendationItemIds() async =>
      (await _prefs).getStringList(_recommendationItemIdsKey) ?? const [];

  @override
  Future<void> saveRecommendationItemId(String value) async {
    final prefs = await _prefs;
    final values = <String>[
      value,
      ...(prefs.getStringList(_recommendationItemIdsKey) ?? const <String>[]),
    ].take(10).toList();
    await prefs.setStringList(_recommendationItemIdsKey, values);
  }
}
