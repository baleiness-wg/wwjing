import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiClient {
  Future<Map<String, dynamic>> get(String path, {String? token}) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: _headers(token),
    );
    return _read(response);
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: {..._headers(token), 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _read(response);
  }

  Map<String, String> _headers(String? token) => {
    'Authorization': ?token,
  };

  Map<String, dynamic> _read(http.Response response) {
    final body = response.body;
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
