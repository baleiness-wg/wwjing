import 'package:flutter_test/flutter_test.dart';
import 'package:wwjing_bookmark/models/shared_link.dart';

void main() {
  test('提取混合文本中的首个 HTTP 链接并保留原文', () {
    const text = '看看这个：https://Example.com/a，备用 https://second.example';
    final result = extractSharedLink(text);
    expect(result?.url, 'https://Example.com/a');
    expect(result?.title, '看看这个：');
    expect(result?.originalText, text);
  });

  test('从抖音分享文案提取作品标题而不是域名', () {
    const text =
        '8.23 复制打开抖音，看看【Senven的图文作品】旅行自由。Hi guys. Today I wan... https://v.douyin.com/5vmPboOhNmQ/ :5pm u@f.bn YMW:/ 08/09';
    final result = extractSharedLink(text);
    expect(result?.url, 'https://v.douyin.com/5vmPboOhNmQ/');
    expect(result?.title, '旅行自由。Hi guys. Today I wan...');
  });

  test('从小红书分享文案提取笔记标题', () {
    const text =
        '动词-英语易混动词，一次分清 lie / lay、rise / rais... https://xhslink.cn/o/8ATAEclrdQd 先复制内容，然后去【小红书】一键查看笔记。';
    final result = extractSharedLink(text);
    expect(result?.title, '动词-英语易混动词，一次分清 lie / lay、rise / rais...');
  });

  test('忽略无链接和非 HTTP 协议', () {
    expect(extractSharedLink('只有中文'), isNull);
    expect(extractSharedLink('ftp://example.com/a'), isNull);
  });
}
