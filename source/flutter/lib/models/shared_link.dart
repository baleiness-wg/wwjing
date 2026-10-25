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
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  return SharedLink(url: rawUrl, title: host, originalText: text.trim());
}
