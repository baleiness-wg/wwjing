import 'package:flutter/services.dart';

class ShareService {
  ShareService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.baleine.wwjing/share');

  final MethodChannel _channel;

  Future<String?> initialText() =>
      _channel.invokeMethod<String>('getInitialShare');

  void listen(void Function(String text) onShare) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shareReceived' && call.arguments is String) {
        onShare(call.arguments as String);
      }
    });
  }
}
