import 'package:bloop/models/task.dart';
import 'package:bloop/utils/due_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 17, 15, 42);

  Task due(DateTime? at, {bool allDay = false}) =>
      Task(title: 't', dueDateTime: at, allDay: allDay);

  DueStatus statusAt(Duration offset) =>
      DueStatus.of(due(now.add(offset)), now);

  test('no due date is anytime', () {
    expect(DueStatus.of(due(null), now).kind, DueKind.anytime);
  });

  test('earlier calendar days are late, counted in days', () {
    final yesterday = DueStatus.of(due(DateTime(2026, 10, 16, 23, 59)), now);
    expect(yesterday.kind, DueKind.late);
    expect(yesterday.daysLate, 1);

    final twoDays = DueStatus.of(due(DateTime(2026, 10, 15, 8)), now);
    expect(twoDays.daysLate, 2);
  });

  test('days late stay whole across a month boundary', () {
    final late = DueStatus.of(
      due(DateTime(2026, 9, 30, 12)),
      DateTime(2026, 10, 2, 9),
    );
    expect(late.daysLate, 2);
  });

  test('earlier today is not late', () {
    expect(statusAt(const Duration(hours: -3)).kind, DueKind.scheduled);
  });

  test('NOW from the due time through 30 minutes after', () {
    expect(statusAt(Duration.zero).kind, DueKind.now);
    expect(statusAt(const Duration(minutes: -30)).kind, DueKind.now);
    expect(statusAt(const Duration(minutes: -31)).kind, DueKind.scheduled);
  });

  test('soon within 60 minutes ahead, minutes rounded up', () {
    final s = statusAt(const Duration(minutes: 18));
    expect(s.kind, DueKind.soon);
    expect(s.minutesAhead, 18);

    expect(statusAt(const Duration(seconds: 30)).minutesAhead, 1);
    expect(statusAt(const Duration(minutes: 60)).kind, DueKind.soon);
    expect(statusAt(const Duration(minutes: 61)).kind, DueKind.scheduled);
  });

  test('all-day tasks are never NOW or soon', () {
    expect(
      DueStatus.of(due(DateTime(2026, 10, 17), allDay: true), now).kind,
      DueKind.scheduled,
    );
    expect(
      DueStatus.of(due(DateTime(2026, 10, 16), allDay: true), now).kind,
      DueKind.late,
    );
  });

  test('lateLabel pluralises', () {
    expect(lateLabel(1), '1 day late');
    expect(lateLabel(2), '2 days late');
  });
}
