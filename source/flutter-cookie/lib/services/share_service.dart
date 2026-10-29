import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ShareService {
  ShareService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.baleine.wwjing.cookie/share');

  final MethodChannel _channel;

  bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<String?> initialText() async {
    if (!_isSupported) return null;
    try {
      return await _channel.invokeMethod<String>('getInitialShare');
    } on MissingPluginException {
      return null;
    }
  }

  void listen(void Function(String text) onShare) {
    if (!_isSupported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shareReceived' && call.arguments is String) {
        onShare(call.arguments as String);
      }
    });
  }
}
