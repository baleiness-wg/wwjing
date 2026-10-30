import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wwjing_bookmark/services/link_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('识别平台 host 和内容标识', () {
    expect(packageForHost('www.bilibili.com'), 'tv.danmaku.bili');
    expect(packageForHost('fakebilibili.com'), isNull);
    expect(
      bilibiliVideoId(Uri.parse('https://www.bilibili.com/video/BV1abc')),
      'BV1abc',
    );
    expect(
      bilibiliVideoId(Uri.parse('https://www.bilibili.com/video/av123')),
      'av123',
    );
    expect(
      xiaohongshuItemId(
        Uri.parse(
          'https://www.xiaohongshu.com/discovery/item/abc123?xsec_token=t',
        ),
      ),
      'abc123',
    );
    expect(
      xiaohongshuItemId(
        Uri.parse(
          'https://www.xiaohongshu.com/login?redirectPath=%2Fexplore%2Fdef456',
        ),
      ),
      'def456',
    );
    expect(
      douyinVideoId(Uri.parse('https://www.iesdouyin.com/share/note/123456')),
      '123456',
    );
    expect(
      isXiaohongshuShortLink(Uri.parse('https://xhslink.cn/o/abc')),
      isTrue,
    );
    expect(
      isCompleteXiaohongshuUrl(
        Uri.parse('https://www.xiaohongshu.com/explore/abc?xsec_token=t'),
      ),
      isTrue,
    );
  });

  testWidgets('Bilibili 按 HTTPS、Deep Link、首页和外部链接递进', (tester) async {
    final calls = <MethodCall>[];
    final channel = MethodChannel(
      'test.bilibili.${DateTime.now().microsecondsSinceEpoch}',
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return false;
    });
    var external = false;
    final launcher = LinkLauncher(
      channel: channel,
      externalUrlOpener: (_) async => external = true,
    );
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );

    await launcher.open(context, 'https://www.bilibili.com/video/BV1abc');

    expect(calls.map((call) => call.method), [
      'openInApp',
      'openInApp',
      'openApp',
    ]);
    expect((calls[1].arguments as Map)['url'], 'bilibili://video/BV1abc');
    expect(external, isTrue);
  });

  testWidgets('小红书和抖音优先使用内容 Deep Link', (tester) async {
    final calls = <MethodCall>[];
    final channel = MethodChannel(
      'test.platform.${DateTime.now().microsecondsSinceEpoch}',
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return true;
    });
    final launcher = LinkLauncher(channel: channel);
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );

    await launcher.open(
      context,
      'https://www.xiaohongshu.com/explore/abc123?xsec_token=t',
    );
    await launcher.open(context, 'https://www.douyin.com/video/987654');

    expect((calls[0].arguments as Map)['url'], 'xhsdiscover://item/abc123');
    expect(
      (calls[1].arguments as Map)['url'],
      'snssdk1128://aweme/detail/987654',
    );
  });
}
