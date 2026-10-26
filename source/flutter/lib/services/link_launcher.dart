import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const _appPackages = <String, String>{
  'bilibili.com': 'tv.danmaku.bili',
  'douyin.com': 'com.ss.android.ugc.aweme',
  'xiaohongshu.com': 'com.xingin.xhs',
  'zhihu.com': 'com.zhihu.android',
  'weibo.com': 'com.sina.weibo',
  'youtube.com': 'com.google.android.youtube',
  'youtu.be': 'com.google.android.youtube',
  'tiktok.com': 'com.zhiliaoapp.musically',
};

const _directHomeHosts = {'douyin.com'};

String? douyinVideoId(Uri uri) {
  final match = RegExp(r'/(?:video|note|aweme/detail)/([0-9]+)').firstMatch(uri.path);
  return match?.group(1);
}

String? packageForHost(String host) {
  final normalized = host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  for (final entry in _appPackages.entries) {
    if (normalized == entry.key || normalized.endsWith('.${entry.key}')) {
      return entry.value;
    }
  }
  return null;
}

Future<bool> _tryOpenInApp(String url, String packageName) async {
  try {
    return await const MethodChannel('com.baleine.wwjing/share').invokeMethod<bool>(
          'openInApp',
          {'url': url, 'packageName': packageName},
        ) ??
        false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

Future<bool> _tryOpenKnownApp(Uri uri) async {
  final packageName = packageForHost(uri.host);
  return packageName != null && await _tryOpenInApp(uri.toString(), packageName);
}

Future<bool> _tryOpenAppHome(String host) async {
  final packageName = packageForHost(host);
  if (packageName == null) return false;
  try {
    return await const MethodChannel('com.baleine.wwjing/share').invokeMethod<bool>(
          'openApp',
          {'packageName': packageName},
        ) ??
        false;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

Future<bool> _tryOpenDouyin(Uri uri) async {
  final videoId = douyinVideoId(uri);
  if (videoId != null) {
    final opened = await _tryOpenInApp(
      'snssdk1128://aweme/detail/$videoId',
      'com.ss.android.ugc.aweme',
    );
    if (opened) return true;
  }
  return _tryOpenAppHome(uri.host);
}

Future<void> openExternalLink(BuildContext context, String value) async {
  final uri = Uri.tryParse(value.trim());
  final valid = uri != null &&
      uri.hasAuthority &&
      (uri.scheme == 'http' || uri.scheme == 'https');
  final directHost = valid && _directHomeHosts.contains(
        uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), ''),
      );
  final opened = valid &&
      (directHost && await _tryOpenDouyin(uri) ||
          !directHost && await _tryOpenKnownApp(uri) ||
          await launchUrl(uri, mode: LaunchMode.externalApplication));

  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('无法打开这个链接')));
  }
}
