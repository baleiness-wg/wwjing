String? cleanCoverUrl(String? rawUrl) {
  if (rawUrl == null || rawUrl.trim().isEmpty) return null;
  var str = rawUrl.trim();

  // 1. 如果是小红书相关图片，才做针对性的嵌套反代剥离
  if (str.contains('xiaohongshu.com') || str.contains('xhscdn.com')) {
    try {
      for (var i = 0; i < 3; i++) {
        if (str.contains('%3A') || str.contains('%2F') || str.contains('%3a') || str.contains('%2f')) {
          str = Uri.decodeComponent(str);
        } else {
          break;
        }
      }
    } catch (_) {}

    final snsIndex = str.indexOf('sns-');
    if (snsIndex != -1) {
      final sub = str.substring(snsIndex);
      return 'https://$sub';
    }
  }

  // 2. 如果存在嵌套协议（且不是正常签名参数），提取最后一个 http:// 或 https://
  final lastHttps = str.lastIndexOf('https://');
  final lastHttp = str.lastIndexOf('http://');
  final lastProtocolIndex = lastHttps > lastHttp ? lastHttps : lastHttp;
  if (lastProtocolIndex > 0) {
    str = str.substring(lastProtocolIndex).replaceFirst(RegExp(r'^http://', caseSensitive: false), 'https://');
  }

  return str;
}
