enum AppType { kitchen, star }

class AppConfig {
  const AppConfig._({
    required this.type,
    required this.appName,
    required this.space,
    required this.supportsRandom,
  });

  factory AppConfig.fromType(String value) => switch (value) {
    'kitchen' => kitchen,
    'star' => star,
    _ => throw ArgumentError.value(
      value,
      'APP_TYPE',
      '必须通过 --dart-define=APP_TYPE=kitchen 或 APP_TYPE=star 指定应用模式',
    ),
  };

  static const kitchen = AppConfig._(
    type: AppType.kitchen,
    appName: '微微鲸厨房',
    space: 'cookie',
    supportsRandom: true,
  );

  static const star = AppConfig._(
    type: AppType.star,
    appName: '微微鲸星标',
    space: 'star',
    supportsRandom: false,
  );

  static AppConfig get current =>
      AppConfig.fromType(const String.fromEnvironment('APP_TYPE'));

  final AppType type;
  final String appName;
  final String space;
  final bool supportsRandom;

  static const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_configuredApiBaseUrl.isNotEmpty) return _configuredApiBaseUrl;
    return 'http://8.141.0.36:3000/api';
  }
}
