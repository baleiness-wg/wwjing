import 'dart:convert';
import 'package:http/http.dart' as http;

class BilibiliMetadata {
  const BilibiliMetadata({
    required this.finalUrl,
    this.title,
    this.description,
    this.coverUrl,
  });

  final String finalUrl;
  final String? title;
  final String? description;
  final String? coverUrl;
}

class BilibiliResolver {
  BilibiliResolver({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static bool isBilibiliUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host.endsWith('bilibili.com') || host.endsWith('b23.tv');
  }

  Future<BilibiliMetadata?> resolve(String sourceUrl) async {
    try {
      var currentUrl = sourceUrl.trim();
      var uri = Uri.tryParse(currentUrl);
      if (uri == null) return null;

      // 如果是 b23.tv 短链，先客户端跟随重定向拿真实页面
      if (uri.host.toLowerCase().endsWith('b23.tv')) {
        final req = http.Request('GET', uri)..followRedirects = false;
        req.headers['User-Agent'] =
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
        req.headers['Referer'] = 'https://www.bilibili.com/';
        final streamed = await _client.send(req).timeout(const Duration(seconds: 4));
        final loc = streamed.headers['location'];
        if (loc != null && loc.isNotEmpty) {
          currentUrl = loc;
          uri = Uri.tryParse(currentUrl) ?? uri;
        }
      }

      // 提取 BV 号或 av 号
      String? bvid;
      String? aid;
      final bvMatch = RegExp(r'/(?:video/)?(BV[a-zA-Z0-9]+)', caseSensitive: false).firstMatch(uri.path);
      if (bvMatch != null) {
        bvid = bvMatch.group(1);
      } else {
        final avMatch = RegExp(r'/(?:video/)?av(\d+)', caseSensitive: false).firstMatch(uri.path);
        if (avMatch != null) aid = avMatch.group(1);
      }

      // 优先直接调用 B 站官方免登录开放 API
      if (bvid != null || aid != null) {
        final queryParam = bvid != null ? 'bvid=$bvid' : 'aid=$aid';
        final officialApi = Uri.parse('https://api.bilibili.com/x/web-interface/view?$queryParam');
        final response = await _client.get(
          officialApi,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
            'Referer': 'https://www.bilibili.com/',
            'Accept': 'application/json, text/plain, */*',
          },
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          if (json['code'] == 0 && json['data'] is Map<String, dynamic>) {
            final data = json['data'] as Map<String, dynamic>;
            var pic = data['pic']?.toString();
            if (pic != null && !pic.contains('transparent.png')) {
              if (pic.startsWith('http://')) {
                pic = pic.replaceFirst('http://', 'https://');
              }
            } else {
              pic = null;
            }
            return BilibiliMetadata(
              finalUrl: currentUrl,
              title: data['title']?.toString(),
              description: data['desc']?.toString(),
              coverUrl: pic,
            );
          }
        }
      }

      // 备用通道
      final bugpkUrl = Uri.parse('https://api.bugpk.com/api/bilibili?url=${Uri.encodeComponent(currentUrl)}');
      final res = await _client.get(
        bugpkUrl,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
          'Referer': 'https://www.bilibili.com/',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        if (json['code'] == 200 && json['data'] is Map<String, dynamic>) {
          final data = json['data'] as Map<String, dynamic>;
          var cover = data['cover']?.toString();
          if (cover != null && cover.startsWith('http://')) {
            cover = cover.replaceFirst('http://', 'https://');
          }
          return BilibiliMetadata(
            finalUrl: currentUrl,
            title: data['title']?.toString(),
            description: data['description']?.toString(),
            coverUrl: cover,
          );
        }
      }
    } catch (_) {}
    return null;
  }
}
