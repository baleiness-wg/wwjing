import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:wwjing_mobile/features/auth/presentation/auth_page.dart';

void main() {
  testWidgets('登录页显示项目标题', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AuthPage()));

    expect(find.text('鲸境'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
  });
}
