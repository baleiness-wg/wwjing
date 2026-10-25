import 'package:shared_preferences/shared_preferences.dart';

abstract interface class PreferencesStore {
  Future<List<String>> recentFolders();
  Future<void> rememberFolder(String id);
  Future<String?> handledClipboardUrl();
  Future<void> setHandledClipboardUrl(String url);
}

class SharedPreferencesStore implements PreferencesStore {
  static const _recentKey = 'recent_folder_ids';
  static const _clipboardKey = 'handled_clipboard_url';

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
}
