class SharedLink {
  const SharedLink({
    required this.url,
    required this.title,
    required this.originalText,
  });

  final String url;
  final String title;
  final String originalText;
}

String titleFallbackForUrl(Uri uri) {
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  final platform = switch (host) {
    'douyin.com' => '抖音视频',
    'bilibili.com' || 'b23.tv' => '哔哩哔哩内容',
    'xiaohongshu.com' => '小红书内容',
    'zhihu.com' => '知乎内容',
    'youtube.com' || 'youtu.be' => 'YouTube 内容',
    _ => host,
  };
  final id = RegExp(r'/(?:video|note|aweme/detail|BV|av)([A-Za-z0-9_-]+)', caseSensitive: false)
      .firstMatch(uri.path)
      ?.group(1);
  return id == null ? platform : '$platform $id';
}

String _titleFromSharedText(String text, int urlStart, Uri uri) {
  var title = text.substring(0, urlStart).trim();
  title = title
      .replaceFirst(RegExp(r'^\s*\d{1,2}:\d{2}\s*'), '')
      .replaceFirst(RegExp(r'^\s*\d{1,2}\.\d{1,2}\s*'), '')
      .replaceFirst(RegExp(r'^\s*复制打开(?:抖音|小红书)[，,、:]?\s*'), '')
      .replaceFirst(RegExp(r'^\s*看看[【\[][^】\]]+[】\]]\s*'), '')
      .replaceFirst(RegExp(r'^\s*先复制内容，然后去【小红书】一键查看笔记[。.!！]?\s*'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (title.isNotEmpty) return title;
  return titleFallbackForUrl(uri);
}

final _httpUrlPattern = RegExp(
  r'https?://[^\s<>"\u3000，。；：！？、]+',
  caseSensitive: false,
);

SharedLink? extractSharedLink(String text) {
  final match = _httpUrlPattern.firstMatch(text);
  if (match == null) return null;
  var rawUrl = match.group(0)!;
  while (rawUrl.isNotEmpty &&
      '.,;:!?，。；：！？、)]}》」』'.contains(rawUrl[rawUrl.length - 1])) {
    rawUrl = rawUrl.substring(0, rawUrl.length - 1);
  }
  final uri = Uri.tryParse(rawUrl);
  if (uri == null ||
      !uri.hasAuthority ||
      !(uri.scheme == 'http' || uri.scheme == 'https')) {
    return null;
  }
  final sharedTitle = _titleFromSharedText(text, match.start, uri);
  return SharedLink(
    url: rawUrl,
    title: sharedTitle,
    originalText: text.trim(),
  );
}
