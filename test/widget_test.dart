import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:har_app/theme.dart';

void main() {
  testWidgets('Theme builds without error', (WidgetTester tester) async {
    final theme = buildAppTheme(Brightness.light);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(body: Center(child: Text('HAR'))),
      ),
    );
    expect(find.text('HAR'), findsOneWidget);
  });
}
