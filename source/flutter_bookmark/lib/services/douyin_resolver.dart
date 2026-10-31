import 'dart:convert';
import 'package:http/http.dart' as http;

class DouyinMetadata {
  const DouyinMetadata({
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

class DouyinResolver {
  DouyinResolver({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static bool isDouyinUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host.endsWith('douyin.com') || host.endsWith('iesdouyin.com');
  }

  Future<DouyinMetadata?> resolve(String sourceUrl) async {
    try {
      final apiUrl = 'https://api.bugpk.com/api/douyin?url=${Uri.encodeComponent(sourceUrl.trim())}';
      final response = await _client.get(
        Uri.parse(apiUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (json['code'] == 200 && json['data'] is Map<String, dynamic>) {
          final data = json['data'] as Map<String, dynamic>;
          var cover = data['cover']?.toString();
          if (cover != null && cover.startsWith('http://')) {
            cover = cover.replaceFirst('http://', 'https://');
          }
          final title = data['title']?.toString() ?? data['desc']?.toString();
          final desc = data['desc']?.toString();
          return DouyinMetadata(
            finalUrl: sourceUrl,
            title: title?.trim().isNotEmpty == true ? title!.trim() : null,
            description: desc?.trim().isNotEmpty == true ? desc!.trim() : null,
            coverUrl: cover?.trim().isNotEmpty == true ? cover!.trim() : null,
          );
        }
      }
    } catch (_) {
      // 容错降级
    }
    return null;
  }
}
