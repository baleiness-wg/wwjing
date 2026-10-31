String? cleanCoverUrl(String? rawUrl) {
  if (rawUrl == null || rawUrl.trim().isEmpty) return null;
  var str = rawUrl.trim();
  try {
    for (var i = 0; i < 3; i++) {
      if (str.contains('%3A') || str.contains('%2F') || str.contains('%3a') || str.contains('%2f')) {
        str = Uri.decodeComponent(str);
      } else {
        break;
      }
    }
  } catch (_) {}

  // 检查小红书 sns 域名的位置
  final snsIndex = str.indexOf('sns-');
  if (snsIndex != -1) {
    final sub = str.substring(snsIndex);
    return 'https://$sub';
  }

  final lastHttps = str.lastIndexOf('https://');
  final lastHttp = str.lastIndexOf('http://');
  final lastProtocolIndex = lastHttps > lastHttp ? lastHttps : lastHttp;
  if (lastProtocolIndex > 0) {
    str = str.substring(lastProtocolIndex).replaceFirst(RegExp(r'^http://', caseSensitive: false), 'https://');
  }
  return str;
}
