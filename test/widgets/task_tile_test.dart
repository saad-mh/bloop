import 'package:bloop/models/task.dart';
import 'package:bloop/models/recurrence.dart';
import 'package:bloop/ui/widgets/task_tile.dart';
import 'package:bloop/utils/date_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_app.dart';

void main() {
  // Saturday 17 October, 3:42 PM.
  final now = DateTime(2026, 10, 17, 15, 42);
  DateTime clock() => now;

  Widget tile(Task task, {VoidCallback? onDelete, VoidCallback? onTap}) =>
      TaskTile(task: task, now: clock, onDelete: onDelete, onTap: onTap);

  // The tightest row: late, flag, bell, long tag.
  // On a 320dp emulator the old row overflowed by 14px.
  Task crowded() => Task(
    title: 'Submit the DBMS lab record',
    tags: ['college-robotics-club'],
    priority: Priority.high,
    reminderMinutes: 10,
    dueDateTime: DateTime(2026, 10, 15, 9, 30),
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
          child: tile(crowded(), onDelete: () {}),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  }

  group('meta line', () {
    testWidgets('undated task reads Anytime', (tester) async {
      await pumpThemed(tester, tile(Task(title: 'Laundry')));
      expect(find.text('Anytime'), findsOneWidget);
    });

    testWidgets('later today shows the time only', (tester) async {
      final due = DateTime(2026, 10, 17, 18, 30);
      await pumpThemed(tester, tile(Task(title: 'Gym', dueDateTime: due)));
      expect(find.text(formatShortTime(due)), findsOneWidget);
    });

    testWidgets('another day shows weekday, date and time', (tester) async {
      final due = DateTime(2026, 10, 19, 23, 59);
      await pumpThemed(tester, tile(Task(title: 'OS', dueDateTime: due)));
      expect(find.text('Mon 19 Oct · ${formatShortTime(due)}'), findsOneWidget);
    });

    testWidgets('all-day task shows the date alone', (tester) async {
      await pumpThemed(
        tester,
        tile(
          Task(
            title: 'Renew books',
            allDay: true,
            dueDateTime: DateTime(2026, 10, 20),
          ),
        ),
      );
      expect(find.text('Tue 20 Oct'), findsOneWidget);
    });

    testWidgets('late task says how many days', (tester) async {
      await pumpThemed(tester, tile(crowded()));
      expect(
        find.textContaining('2 days late', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('shows the first tag', (tester) async {
      await pumpThemed(tester, tile(Task(title: 'Standup', tags: ['work'])));
      expect(find.text('work'), findsOneWidget);
    });
  });

  group('NOW and soon', () {
    testWidgets('NOW tag and clock time once the time has arrived', (
      tester,
    ) async {
      final due = DateTime(2026, 10, 17, 15, 30);
      await pumpThemed(tester, tile(Task(title: 'Reply', dueDateTime: due)));
      expect(find.text('NOW'), findsOneWidget);
      expect(
        find.textContaining(formatShortTime(due), findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('In ', findRichText: true), findsNothing);
    });

    testWidgets('soon replaces the clock lead with In N min', (tester) async {
      final due = DateTime(2026, 10, 17, 16, 0);
      await pumpThemed(tester, tile(Task(title: 'Budget', dueDateTime: due)));
      expect(
        find.textContaining('In 18 min', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('· ${formatShortTime(due)}', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('NOW'), findsNothing);
    });

    testWidgets('NOW is filled darker than soon', (tester) async {
      Future<Color?> fillOf(Task task) async {
        await pumpThemed(tester, tile(task));
        final material = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(TaskTile),
                matching: find.byType(Material),
              )
              .first,
        );
        return material.color;
      }

      final nowFill = await fillOf(
        Task(title: 'a', dueDateTime: DateTime(2026, 10, 17, 15, 40)),
      );
      final soonFill = await fillOf(
        Task(title: 'b', dueDateTime: DateTime(2026, 10, 17, 16, 0)),
      );
      final plain = await fillOf(Task(title: 'c'));

      expect(plain, Colors.transparent);
      expect(soonFill, isNot(plain));
      expect(nowFill, isNot(soonFill));
    });

    testWidgets('minute tick moves a row from soon into NOW', (tester) async {
      var current = DateTime(2026, 10, 17, 15, 59, 30);
      final task = Task(
        title: 'Budget',
        dueDateTime: DateTime(2026, 10, 17, 16, 0),
      );
      await pumpThemed(tester, TaskTile(task: task, now: () => current));
      expect(
        find.textContaining('In 1 min', findRichText: true),
        findsOneWidget,
      );

      current = DateTime(2026, 10, 17, 16, 0, 1);
      await tester.pump(const Duration(seconds: 31));
      expect(find.text('NOW'), findsOneWidget);
    });
  });

  group('flag and bell', () {
    testWidgets('flag only for high priority', (tester) async {
      await pumpThemed(
        tester,
        tile(Task(title: 'a', priority: Priority.medium)),
      );
      expect(find.bySemanticsLabel('High priority'), findsNothing);

      await pumpThemed(tester, tile(Task(title: 'a', priority: Priority.high)));
      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    });

    testWidgets('late high-priority flag is filled', (tester) async {
      await pumpThemed(tester, tile(crowded()));
      expect(find.byIcon(Icons.flag), findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsNothing);
    });

    testWidgets('bell only when a reminder is set', (tester) async {
      await pumpThemed(tester, tile(Task(title: 'a')));
      expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);

      await pumpThemed(tester, tile(Task(title: 'a', reminderMinutes: 5)));
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    });
  });

  group('interaction', () {
    testWidgets('the circle completes, the row does not', (tester) async {
      final toggled = <bool?>[];
      var opened = 0;
      await pumpThemed(
        tester,
        TaskTile(
          task: Task(title: 'a'),
          now: clock,
          onToggleComplete: toggled.add,
          onTap: () => opened++,
        ),
      );

      await tester.tap(find.byType(InkResponse));
      expect(toggled, [true]);
      expect(opened, 0);

      await tester.tap(find.text('a'));
      expect(toggled, [true]);
      expect(opened, 1);
    });

    testWidgets('circle hit area is at least 48dp', (tester) async {
      await pumpThemed(
        tester,
        TaskTile(
          task: Task(title: 'a'),
          now: clock,
          onToggleComplete: (_) {},
        ),
      );
      final size = tester.getSize(find.byType(InkResponse));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('actions show only while expanded', (tester) async {
      Widget expandable({required bool expanded}) => TaskTile(
        task: Task(title: 'a'),
        now: clock,
        expanded: expanded,
        actions: const Text('the actions'),
      );

      await pumpThemed(tester, expandable(expanded: false));
      expect(find.text('the actions'), findsNothing);

      await pumpThemed(tester, expandable(expanded: true));
      await tester.pumpAndSettle();
      expect(find.text('the actions'), findsOneWidget);

      await pumpThemed(tester, expandable(expanded: false));
      await tester.pumpAndSettle();
      expect(find.text('the actions'), findsNothing);
    });

    testWidgets('tapping the actions does not tap the row', (tester) async {
      var opened = 0;
      await pumpThemed(
        tester,
        TaskTile(
          task: Task(title: 'a'),
          now: clock,
          expanded: true,
          onTap: () => opened++,
          actions: const Text('the actions'),
        ),
      );

      await tester.tap(find.text('the actions'));
      expect(opened, 0);
    });

    testWidgets('an open row is tinted, NOW keeps its own fill', (
      tester,
    ) async {
      Future<Color?> fillOf(Task task, {required bool expanded}) async {
        await pumpThemed(
          tester,
          TaskTile(
            task: task,
            now: clock,
            expanded: expanded,
            actions: const Text('the actions'),
          ),
        );
        return tester
            .widget<Material>(
              find
                  .descendant(
                    of: find.byType(TaskTile),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .color;
      }

      final closed = await fillOf(Task(title: 'a'), expanded: false);
      final open = await fillOf(Task(title: 'a'), expanded: true);
      expect(closed, Colors.transparent);
      expect(open, isNot(closed));

      final nowTask = Task(
        title: 'b',
        dueDateTime: DateTime(2026, 10, 17, 15, 40),
      );
      expect(
        await fillOf(nowTask, expanded: true),
        await fillOf(nowTask, expanded: false),
      );
    });

    testWidgets('tells screen readers whether the row is expanded', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      Widget expandable({required bool expanded}) => TaskTile(
        task: Task(title: 'Budget'),
        now: clock,
        expanded: expanded,
        onTap: () {},
        actions: const Text('the actions'),
      );

      await pumpThemed(tester, expandable(expanded: false));
      expect(
        tester.getSemantics(find.text('Budget')),
        isSemantics(hasExpandedState: true, isExpanded: false),
      );

      await pumpThemed(tester, expandable(expanded: true));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('Budget')),
        isSemantics(hasExpandedState: true, isExpanded: true),
      );
      handle.dispose();
    });

    testWidgets('swiping across the actions does not delete', (tester) async {
      var deleted = 0;
      await pumpThemed(
        tester,
        TaskTile(
          task: Task(title: 'a'),
          now: clock,
          expanded: true,
          onDelete: () => deleted++,
          actions: const SizedBox(height: 60, child: Center(child: Text('x'))),
        ),
      );

      await tester.drag(find.text('x'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(deleted, 0);

      await tester.drag(find.text('a'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(deleted, 1, reason: 'the row itself still swipes away');
    });

    testWidgets('a repeating task reappears once moved to its next date', (
      tester,
    ) async {
      final today = Task(
        title: 'Water plants',
        recurrence: Recurrence.daily,
        dueDateTime: DateTime(2026, 10, 17, 18),
      );
      Widget tile(Task task) => TaskTile(
        task: task,
        now: clock,
        animateOnComplete: true,
        onToggleComplete: (_) {},
      );
      double opacity() =>
          tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

      await pumpThemed(tester, tile(today));
      await tester.tap(find.byType(InkResponse));
      await tester.pump(const Duration(milliseconds: 300));
      expect(opacity(), 0);

      // The same task, id and all, comes back with tomorrow's date.
      await pumpThemed(
        tester,
        tile(today.copyWith(dueDateTime: DateTime(2026, 10, 18, 18))),
      );
      expect(opacity(), 1);
    });

    testWidgets('swiping left deletes', (tester) async {
      var deleted = 0;
      await pumpThemed(
        tester,
        tile(Task(title: 'a'), onDelete: () => deleted++),
      );
      await tester.drag(find.text('a'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(deleted, 1);
    });
  });
}
