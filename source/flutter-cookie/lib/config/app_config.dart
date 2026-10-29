class AppConfig {
  const AppConfig._();

  static const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_configuredApiBaseUrl.isNotEmpty) return _configuredApiBaseUrl;
    return 'http://8.141.0.36:3000/api';
  }
}
