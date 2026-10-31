import 'package:flutter_test/flutter_test.dart';
import 'package:wwjing_bookmark/config/app_config.dart';

void main() {
  test('kitchen 模式映射到 cookie 空间和随机能力', () {
    final config = AppConfig.fromType('kitchen');

    expect(config.type, AppType.kitchen);
    expect(config.appName, '疯狂的厨房');
    expect(config.space, 'cookie');
    expect(config.supportsRandom, isTrue);
  });

  test('star 模式映射到 star 空间且不提供随机能力', () {
    final config = AppConfig.fromType('star');

    expect(config.type, AppType.star);
    expect(config.appName, '鲸界');
    expect(config.space, 'star');
    expect(config.supportsRandom, isFalse);
  });

  test('缺失或非法 APP_TYPE 会明确失败', () {
    expect(() => AppConfig.fromType(''), throwsArgumentError);
    expect(() => AppConfig.fromType('other'), throwsArgumentError);
  });
}
