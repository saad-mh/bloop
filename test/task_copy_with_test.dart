import 'package:bloop/models/task.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Task.copyWith', () {
    test('an empty reminder list clears the reminder', () {
      final task = Task(
        title: 'a',
        reminderMinutes: 30,
        reminderMinutesList: [30],
      );

      final cleared = task.copyWith(remindersBefore: const []);

      expect(cleared.remindersBefore, isEmpty);
      expect(cleared.reminderBefore, isNull);
    });

    test('a legacy single reminder is kept when reminders are not passed', () {
      final task = Task(title: 'a', reminderMinutes: 30);

      expect(task.copyWith(title: 'b').remindersBefore, [
        const Duration(minutes: 30),
      ]);
    });

    test('new reminders replace the old ones', () {
      final task = Task(
        title: 'a',
        reminderMinutes: 30,
        reminderMinutesList: [30],
      );

      final changed = task.copyWith(
        remindersBefore: const [Duration(minutes: 5), Duration(hours: 1)],
      );

      expect(changed.remindersBefore, [
        const Duration(minutes: 5),
        const Duration(hours: 1),
      ]);
    });

    test('clearDueDateTime and clearNotes remove them', () {
      final task = Task(
        title: 'a',
        notes: 'n',
        dueDateTime: DateTime(2026, 10, 17, 9),
      );

      final cleared = task.copyWith(clearDueDateTime: true, clearNotes: true);

      expect(cleared.dueDateTime, isNull);
      expect(cleared.notes, isNull);
    });

    test('null leaves the date and notes alone', () {
      final due = DateTime(2026, 10, 17, 9);
      final task = Task(title: 'a', notes: 'n', dueDateTime: due);

      final same = task.copyWith(title: 'b');

      expect(same.dueDateTime, due);
      expect(same.notes, 'n');
    });
  });
}
