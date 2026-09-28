import 'package:flutter_test/flutter_test.dart';

import 'package:wwjing_mobile/app.dart';

void main() {
  testWidgets('登录页显示项目标题', (WidgetTester tester) async {
    await tester.pumpWidget(const WwjingApp());

    expect(find.text('鲸境'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
  });
}
