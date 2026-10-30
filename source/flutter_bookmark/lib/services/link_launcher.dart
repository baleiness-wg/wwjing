import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const bookmarkChannelName = 'com.baleine.wwjing.bookmark/share';

const _appPackages = <String, String>{
  'bilibili.com': 'tv.danmaku.bili',
  'b23.tv': 'tv.danmaku.bili',
  'douyin.com': 'com.ss.android.ugc.aweme',
  'iesdouyin.com': 'com.ss.android.ugc.aweme',
  'xiaohongshu.com': 'com.xingin.xhs',
  'xhslink.cn': 'com.xingin.xhs',
  'xhslink.com': 'com.xingin.xhs',
  'zhihu.com': 'com.zhihu.android',
  'weibo.com': 'com.sina.weibo',
  'youtube.com': 'com.google.android.youtube',
  'youtu.be': 'com.google.android.youtube',
  'tiktok.com': 'com.zhiliaoapp.musically',
};

typedef ExternalUrlOpener = Future<bool> Function(Uri uri);

String normalizedHost(String host) =>
    host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');

bool hostMatches(String host, String domain) {
  final normalized = normalizedHost(host);
  return normalized == domain || normalized.endsWith('.$domain');
}

String? packageForHost(String host) {
  for (final entry in _appPackages.entries) {
    if (hostMatches(host, entry.key)) return entry.value;
  }
  return null;
}

String? bilibiliVideoId(Uri uri) {
  final match = RegExp(
    r'/(?:video/)?((?:BV)[a-zA-Z0-9]+|(?:av)[0-9]+)',
    caseSensitive: false,
  ).firstMatch(uri.path);
  return match?.group(1);
}

String? douyinVideoId(Uri uri) {
  final match = RegExp(
    r'/(?:video|note|aweme/detail|share/video|share/note)/([0-9]+)',
  ).firstMatch(uri.path);
  return match?.group(1);
}

String? xiaohongshuItemId(Uri uri) {
  final direct = RegExp(r'/(?:discovery/item|explore)/([a-zA-Z0-9]+)')
      .firstMatch(uri.path);
  if (direct != null) return direct.group(1);
  final redirectPath = uri.queryParameters['redirectPath'];
  if (redirectPath == null) return null;
  final decoded = Uri.decodeComponent(redirectPath);
  return RegExp(r'/(?:discovery/item|explore)/([a-zA-Z0-9]+)')
      .firstMatch(decoded)
      ?.group(1);
}

bool isXiaohongshuShortLink(Uri uri) =>
    hostMatches(uri.host, 'xhslink.cn') || hostMatches(uri.host, 'xhslink.com');

bool isCompleteXiaohongshuUrl(Uri uri) =>
    hostMatches(uri.host, 'xiaohongshu.com') && xiaohongshuItemId(uri) != null;

class LinkLauncher {
  const LinkLauncher({
    this.channel = const MethodChannel(bookmarkChannelName),
    this.externalUrlOpener,
  });

  final MethodChannel channel;
  final ExternalUrlOpener? externalUrlOpener;

  Future<bool> open(BuildContext context, String value) async {
    final uri = Uri.tryParse(value.trim());
    final valid =
        uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'http' || uri.scheme == 'https');
    final opened = valid && await _openUri(uri);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('无法打开这个链接')));
    }
    return opened;
  }

  Future<bool> _openUri(Uri uri) async {
    final host = normalizedHost(uri.host);
    if (hostMatches(host, 'bilibili.com') || hostMatches(host, 'b23.tv')) {
      return await _openBilibili(uri) || await _openExternal(uri);
    }
    if (hostMatches(host, 'xiaohongshu.com') ||
        hostMatches(host, 'xhslink.cn') ||
        hostMatches(host, 'xhslink.com')) {
      return await _openXiaohongshu(uri) || await _openExternal(uri);
    }
    if (hostMatches(host, 'douyin.com') || hostMatches(host, 'iesdouyin.com')) {
      return await _openDouyin(uri) || await _openExternal(uri);
    }
    final packageName = packageForHost(host);
    if (packageName != null && await _openInApp(uri.toString(), packageName)) {
      return true;
    }
    return _openExternal(uri);
  }

  Future<bool> _openBilibili(Uri uri) async {
    const packageName = 'tv.danmaku.bili';
    if (await _openInApp(uri.toString(), packageName)) return true;
    final id = bilibiliVideoId(uri);
    if (id != null && await _openInApp('bilibili://video/$id', packageName)) {
      return true;
    }
    return _openApp(packageName);
  }

  Future<bool> _openXiaohongshu(Uri uri) async {
    const packageName = 'com.xingin.xhs';
    final id = xiaohongshuItemId(uri);
    if (id != null && await _openInApp('xhsdiscover://item/$id', packageName)) {
      return true;
    }
    if (await _openInApp(uri.toString(), packageName)) return true;
    return _openApp(packageName);
  }

  Future<bool> _openDouyin(Uri uri) async {
    const packageName = 'com.ss.android.ugc.aweme';
    final id = douyinVideoId(uri);
    if (id != null &&
        await _openInApp('snssdk1128://aweme/detail/$id', packageName)) {
      return true;
    }
    return _openApp(packageName);
  }

  Future<bool> _openInApp(String url, String packageName) async {
    try {
      return await channel.invokeMethod<bool>('openInApp', {
            'url': url,
            'packageName': packageName,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> _openApp(String packageName) async {
    try {
      return await channel.invokeMethod<bool>('openApp', {
            'packageName': packageName,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> _openExternal(Uri uri) => externalUrlOpener != null
      ? externalUrlOpener!(uri)
      : launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<bool> openExternalLink(BuildContext context, String value) =>
    const LinkLauncher().open(context, value);
