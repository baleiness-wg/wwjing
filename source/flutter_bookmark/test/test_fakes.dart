import 'package:wwjing_bookmark/services/preferences_store.dart';
import 'package:wwjing_bookmark/services/token_store.dart';

class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.value]);
  String? value;
  @override
  Future<void> clear() async => value = null;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async => value = token;
}

class MemoryPreferencesStore implements PreferencesStore {
  List<String> recent = [];
  String? clipboard;
  @override
  Future<String?> handledClipboardUrl() async => clipboard;
  @override
  Future<List<String>> recentFolders() async => recent;
  @override
  Future<void> rememberFolder(String id) async =>
      recent = [id, ...recent.where((value) => value != id)];
  @override
  Future<void> setHandledClipboardUrl(String url) async => clipboard = url;
}
