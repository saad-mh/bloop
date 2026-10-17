import 'package:bloop/models/task.dart';
import 'package:bloop/ui/widgets/task_tile.dart';
import 'package:bloop/utils/date_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_app.dart';

void main() {
  // The tightest row: overdue badge, delete button, long tag, date and time.
  // On a 320dp emulator this overflowed by 14px before the meta line wrapped.
  Task crowded() => Task(
    title: 'Submit the DBMS lab record',
    tags: ['college-robotics-club'],
    dueDateTime: DateTime.now().subtract(const Duration(days: 1)),
  );

  for (final scale in [1.0, 1.5]) {
    testWidgets('crowded row fits 320dp at ${scale}x text', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 2000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await pumpThemed(
        tester,
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: TaskTile(task: crowded(), onDelete: () {}),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shows tag, date and time', (tester) async {
    await pumpThemed(
      tester,
      TaskTile(
        task: Task(
          title: 'Standup',
          tags: ['work'],
          dueDateTime: DateTime(2026, 10, 17, 9, 30),
        ),
      ),
    );

    expect(find.text('work'), findsOneWidget);
    expect(find.text('Oct 17'), findsOneWidget);
    expect(
      find.text(formatShortTime(DateTime(2026, 10, 17, 9, 30))),
      findsOneWidget,
    );
  });
}
