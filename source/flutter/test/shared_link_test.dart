import 'package:flutter_test/flutter_test.dart';
import 'package:wwjing_bookmarks/models/shared_link.dart';

void main() {
  test('提取混合文本中的首个 HTTP 链接并保留原文', () {
    const text = '看看这个：https://Example.com/a，备用 https://second.example';
    final result = extractSharedLink(text);
    expect(result?.url, 'https://Example.com/a');
    expect(result?.title, 'example.com');
    expect(result?.originalText, text);
  });

  test('忽略无链接和非 HTTP 协议', () {
    expect(extractSharedLink('只有中文'), isNull);
    expect(extractSharedLink('ftp://example.com/a'), isNull);
  });
}
