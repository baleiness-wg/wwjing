import 'dart:convert';
import 'dart:io';

import '../config/app_config.dart';

class ApiClient {
  Future<Map<String, dynamic>> get(String path, {String? token}) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('${AppConfig.apiBaseUrl}$path'),
      );
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, token);
      }
      return await _read(await request.close());
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.parse('${AppConfig.apiBaseUrl}$path'),
      );
      request.headers.contentType = ContentType.json;
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, token);
      }
      request.write(jsonEncode(body));
      return await _read(await request.close());
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> _read(HttpClientResponse response) async {
    final body = await response.transform(utf8.decoder).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(
        data['message']?.toString() ?? '请求失败',
        response.statusCode,
      );
    }
    return data;
  }
}

class ApiException implements Exception {
  const ApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
