import 'package:bloop/models/task.dart';
import 'package:bloop/utils/focus_pick.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Saturday 17 October 2026, 3:00 PM local.
  final now = DateTime(2026, 10, 17, 15);

  Task task(
    String id, {
    DateTime? due,
    bool done = false,
    bool allDay = false,
    DateTime? created,
  }) => Task(
    id: id,
    title: id,
    dueDateTime: due,
    allDay: allDay,
    isCompleted: done,
    createdAt: created ?? DateTime(2026, 10, 1),
  );

  group('focusCandidates', () {
    test('keeps open tasks due today or earlier, soonest first', () {
      final list = focusCandidates([
        task('later today', due: DateTime(2026, 10, 17, 20)),
        task('yesterday', due: DateTime(2026, 10, 16, 9)),
        task('tomorrow', due: DateTime(2026, 10, 18, 9)),
        task('undated'),
        task('done', due: DateTime(2026, 10, 17, 9), done: true),
        task('this morning', due: DateTime(2026, 10, 17, 9)),
      ], now);

      expect(list.map((t) => t.id), [
        'yesterday',
        'this morning',
        'later today',
      ]);
    });

    test('is empty when nothing is due', () {
      expect(focusCandidates([task('undated')], now), isEmpty);
    });
  });

  group('defaultFocusTask', () {
    test('prefers a task that is NOW', () {
      final pick = defaultFocusTask([
        task('evening', due: DateTime(2026, 10, 17, 20)),
        task('just due', due: DateTime(2026, 10, 17, 14, 45)),
      ], now);

      expect(pick?.id, 'just due');
    });

    test('takes the first task that is soon over a later one', () {
      final pick = defaultFocusTask([
        task('evening', due: DateTime(2026, 10, 17, 20)),
        task('in 30 min', due: DateTime(2026, 10, 17, 15, 30)),
      ], now);

      expect(pick?.id, 'in 30 min');
    });

    test('falls back to the most recently added task on Today', () {
      final pick = defaultFocusTask([
        task(
          'old',
          due: DateTime(2026, 10, 17, 20),
          created: DateTime(2026, 10, 2),
        ),
        task(
          'new',
          due: DateTime(2026, 10, 17, 21),
          created: DateTime(2026, 10, 15),
        ),
      ], now);

      expect(pick?.id, 'new');
    });

    test('an all-day task is never NOW, so the fallback applies', () {
      final pick = defaultFocusTask([
        task('all day', due: DateTime(2026, 10, 17), allDay: true),
      ], now);

      expect(pick?.id, 'all day');
    });

    test(
      'offers the longest-waiting overdue task when nothing is due today',
      () {
        final pick = defaultFocusTask([
          task('newer', due: DateTime(2026, 10, 16, 9)),
          task('older', due: DateTime(2026, 10, 14, 9)),
        ], now);

        expect(pick?.id, 'older');
      },
    );

    test('Today still beats overdue', () {
      final pick = defaultFocusTask([
        task('overdue', due: DateTime(2026, 10, 15, 9)),
        task('evening', due: DateTime(2026, 10, 17, 20)),
      ], now);

      expect(pick?.id, 'evening');
    });

    test('is null with nothing to do', () {
      expect(defaultFocusTask(const [], now), isNull);
    });
  });
}
