import 'package:bloop/ui/widgets/task_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_app.dart';

void main() {
  Widget bar({
    int minutes = 25,
    VoidCallback? onFocus,
    VoidCallback? onSnooze,
    VoidCallback? onTomorrow,
    VoidCallback? onEdit,
  }) => TaskActionBar(
    focusMinutes: minutes,
    onFocus: onFocus ?? () {},
    onSnooze: onSnooze ?? () {},
    onTomorrow: onTomorrow ?? () {},
    onEdit: onEdit ?? () {},
  );

  testWidgets('shows the four actions with the focus length', (tester) async {
    await pumpThemed(tester, bar(minutes: 45));

    expect(find.text('Focus 45m'), findsOneWidget);
    expect(find.text('Snooze 1h'), findsOneWidget);
    expect(find.text('Tomorrow'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets('each button calls its own callback', (tester) async {
    final taps = <String>[];
    await pumpThemed(
      tester,
      bar(
        onFocus: () => taps.add('focus'),
        onSnooze: () => taps.add('snooze'),
        onTomorrow: () => taps.add('tomorrow'),
        onEdit: () => taps.add('edit'),
      ),
    );

    await tester.tap(find.text('Focus 25m'));
    await tester.tap(find.text('Snooze 1h'));
    await tester.tap(find.text('Tomorrow'));
    await tester.tap(find.text('Edit'));

    expect(taps, ['focus', 'snooze', 'tomorrow', 'edit']);
  });

  testWidgets('buttons are at least 44dp tall', (tester) async {
    await pumpThemed(tester, bar());

    for (final button in tester.widgetList(find.byType(OutlinedButton))) {
      final size = tester.getSize(find.byWidget(button));
      expect(size.height, greaterThanOrEqualTo(44));
    }
  });

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('fits 320dp at ${scale}x text', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 2000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await pumpThemed(
        tester,
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: bar(minutes: 180),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Tomorrow'), findsOneWidget);
    });
  }
}
