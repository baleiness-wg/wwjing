class AppConfig {
  static const appName = '鲸境';
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://123.57.160.236:3000',
  );
}
