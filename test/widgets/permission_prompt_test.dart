import 'package:bloop/ui/widgets/permission_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_app.dart';

void main() {
  /// Opens the prompt from a button and records what it resolves to.
  Future<List<bool>> open(
    WidgetTester tester,
    PermissionKind kind, {
    int step = 1,
    int steps = 1,
    bool dark = false,
  }) async {
    final results = <bool>[];
    await pumpThemed(
      tester,
      dark: dark,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => results.add(
            await showPermissionPrompt(
              context,
              kind: kind,
              step: step,
              steps: steps,
            ),
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('notifications has its own headline and button', (tester) async {
    await open(tester, PermissionKind.notifications);
    expect(find.text('Get nudged when it counts'), findsOneWidget);
    expect(find.text('Allow notifications'), findsOneWidget);
    expect(find.text('Allow exact timing'), findsNothing);
  });

  testWidgets('exact alarms has its own headline and button', (tester) async {
    await open(tester, PermissionKind.exactAlarm);
    expect(find.text('Right on the minute'), findsOneWidget);
    expect(find.text('Allow exact timing'), findsOneWidget);
    expect(find.text('Allow notifications'), findsNothing);
  });

  testWidgets('the main button resolves to true', (tester) async {
    final results = await open(tester, PermissionKind.notifications);
    await tester.tap(find.text('Allow notifications'));
    await tester.pumpAndSettle();
    expect(results, [true]);
  });

  testWidgets('Not now resolves to false', (tester) async {
    final results = await open(tester, PermissionKind.exactAlarm);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(results, [false]);
  });

  testWidgets('a stray tap or back press does not close it', (tester) async {
    final results = await open(tester, PermissionKind.notifications);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Allow notifications'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Allow notifications'), findsOneWidget);
    expect(results, isEmpty);
  });

  testWidgets('scrolls instead of overflowing with large text', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await open(tester, PermissionKind.exactAlarm, steps: 2, step: 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the step only when there is more than one', (
    tester,
  ) async {
    await open(tester, PermissionKind.notifications);
    expect(find.bySemanticsLabel('Step 1 of 2'), findsNothing);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    await open(tester, PermissionKind.notifications, steps: 2);
    expect(find.bySemanticsLabel('Step 1 of 2'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('fits a small phone in ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await open(
        tester,
        PermissionKind.exactAlarm,
        steps: 2,
        step: 2,
        dark: dark,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
