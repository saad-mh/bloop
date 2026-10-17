import 'package:bloop/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] inside the real light or dark theme.
Future<void> pumpThemed(
  WidgetTester tester,
  Widget child, {
  bool dark = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark : AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}
