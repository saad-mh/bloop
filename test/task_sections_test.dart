import 'package:bloop/models/task.dart';
import 'package:bloop/utils/task_sections.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Saturday 17 October, 3:42 PM.
  final now = DateTime(2026, 10, 17, 15, 42);

  Task task(String id, {DateTime? due, bool allDay = false}) =>
      Task(id: id, title: id, dueDateTime: due, allDay: allDay);

  List<String> ids(TaskGroup group) => [for (final t in group.tasks) t.id];

  group('sectionFor', () {
    test('no due date is Whenever', () {
      expect(sectionFor(task('a'), now), TaskSection.whenever);
    });

    test('an earlier day is Overdue', () {
      expect(
        sectionFor(task('a', due: DateTime(2026, 10, 16, 23, 59)), now),
        TaskSection.overdue,
      );
    });

    test('later today stays in Today, even once the time has passed', () {
      expect(
        sectionFor(task('a', due: DateTime(2026, 10, 17, 15, 30)), now),
        TaskSection.today,
      );
      expect(
        sectionFor(task('b', due: DateTime(2026, 10, 17, 23, 59)), now),
        TaskSection.today,
      );
    });

    test('an all-day task due today is Today', () {
      expect(
        sectionFor(task('a', due: DateTime(2026, 10, 17), allDay: true), now),
        TaskSection.today,
      );
    });

    test('midnight tomorrow is Upcoming, midnight today is Today', () {
      expect(
        sectionFor(task('a', due: DateTime(2026, 10, 18)), now),
        TaskSection.upcoming,
      );
      expect(
        sectionFor(task('b', due: DateTime(2026, 10, 17)), now),
        TaskSection.today,
      );
    });

    test('far-future dates are Upcoming', () {
      expect(
        sectionFor(task('a', due: DateTime(2027, 1, 1)), now),
        TaskSection.upcoming,
      );
    });

    test('a UTC now is read in local time', () {
      expect(
        sectionFor(task('a', due: DateTime(2026, 10, 17, 9)), now.toUtc()),
        TaskSection.today,
      );
    });

    test('a UTC due date is read in local time', () {
      final due = DateTime(2026, 10, 17, 9).toUtc();
      expect(sectionFor(task('a', due: due), now), TaskSection.today);
    });
  });

  group('groupTasksBySection', () {
    test('no tasks gives no groups', () {
      expect(groupTasksBySection(const [], now), isEmpty);
    });

    test('orders sections Overdue, Today, Upcoming, Whenever', () {
      final groups = groupTasksBySection([
        task('whenever'),
        task('upcoming', due: DateTime(2026, 10, 20)),
        task('today', due: DateTime(2026, 10, 17, 18)),
        task('overdue', due: DateTime(2026, 10, 15)),
      ], now);

      expect(groups.map((g) => g.section), TaskSection.values);
      expect(groups.map(ids), [
        ['overdue'],
        ['today'],
        ['upcoming'],
        ['whenever'],
      ]);
    });

    test('hides empty sections', () {
      final groups = groupTasksBySection([
        task('a', due: DateTime(2026, 10, 17, 18)),
        task('b'),
      ], now);

      expect(groups.map((g) => g.section), [
        TaskSection.today,
        TaskSection.whenever,
      ]);
    });

    test('keeps the incoming order within a section', () {
      final groups = groupTasksBySection([
        task('first', due: DateTime(2026, 10, 14)),
        task('second', due: DateTime(2026, 10, 15)),
        task('third', due: DateTime(2026, 10, 16)),
      ], now);

      expect(groups, hasLength(1));
      expect(ids(groups.single), ['first', 'second', 'third']);
    });

    test('puts every task in exactly one group', () {
      final tasks = [
        for (var i = -3; i <= 3; i++)
          task('d$i', due: DateTime(2026, 10, 17 + i)),
        task('none'),
      ];

      final groups = groupTasksBySection(tasks, now);

      expect(groups.expand((g) => g.tasks).length, tasks.length);
    });
  });
}
