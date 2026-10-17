import 'package:bloop/models/task.dart';
import 'package:bloop/utils/task_reschedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Saturday 17 October, 3:42 PM.
  final now = DateTime(2026, 10, 17, 15, 42);

  group('snoozed', () {
    test('a task due later moves on by an hour from its due time', () {
      final task = Task(
        title: 'a',
        dueDateTime: DateTime(2026, 10, 17, 18, 30),
      );
      expect(snoozed(task, now).dueDateTime, DateTime(2026, 10, 17, 19, 30));
    });

    test('a task already due lands an hour from now', () {
      final task = Task(
        title: 'a',
        dueDateTime: DateTime(2026, 10, 17, 15, 30),
      );
      expect(snoozed(task, now).dueDateTime, DateTime(2026, 10, 17, 16, 42));
    });

    test('a task days late lands an hour from now', () {
      final task = Task(title: 'a', dueDateTime: DateTime(2026, 10, 15, 9, 30));
      expect(snoozed(task, now).dueDateTime, DateTime(2026, 10, 17, 16, 42));
    });

    test('an undated task becomes timed an hour from now', () {
      final result = snoozed(Task(title: 'a'), now);
      expect(result.dueDateTime, DateTime(2026, 10, 17, 16, 42));
      expect(result.allDay, isFalse);
    });

    test('an all-day task becomes timed an hour from now', () {
      final task = Task(
        title: 'a',
        allDay: true,
        dueDateTime: DateTime(2026, 10, 17),
      );
      final result = snoozed(task, now);
      expect(result.dueDateTime, DateTime(2026, 10, 17, 16, 42));
      expect(result.allDay, isFalse);
    });

    test('keeps everything else and stamps updatedAt', () {
      final task = Task(
        title: 'a',
        priority: Priority.high,
        tags: ['college'],
        reminderMinutes: 10,
        dueDateTime: DateTime(2026, 10, 17, 18, 30),
      );
      final result = snoozed(task, now);
      expect(result.id, task.id);
      expect(result.title, 'a');
      expect(result.priority, Priority.high);
      expect(result.tags, ['college']);
      expect(result.reminderMinutes, 10);
      expect(result.updatedAt, now.toUtc());
    });
  });

  group('movedToTomorrow', () {
    test('a timed task keeps its time of day', () {
      final task = Task(title: 'a', dueDateTime: DateTime(2026, 10, 15, 9, 30));
      final result = movedToTomorrow(task, now);
      expect(result.dueDateTime, DateTime(2026, 10, 18, 9, 30));
      expect(result.allDay, isFalse);
    });

    test('a task due later today moves to the same time tomorrow', () {
      final task = Task(
        title: 'a',
        dueDateTime: DateTime(2026, 10, 17, 23, 59),
      );
      expect(
        movedToTomorrow(task, now).dueDateTime,
        DateTime(2026, 10, 18, 23, 59),
      );
    });

    test('an undated task becomes all-day tomorrow', () {
      final result = movedToTomorrow(Task(title: 'a'), now);
      expect(result.dueDateTime, DateTime(2026, 10, 18));
      expect(result.allDay, isTrue);
    });

    test('an all-day task stays all-day, tomorrow', () {
      final task = Task(
        title: 'a',
        allDay: true,
        dueDateTime: DateTime(2026, 10, 20),
      );
      final result = movedToTomorrow(task, now);
      expect(result.dueDateTime, DateTime(2026, 10, 18));
      expect(result.allDay, isTrue);
    });

    test('rolls over the end of the month', () {
      final result = movedToTomorrow(
        Task(title: 'a', dueDateTime: DateTime(2026, 10, 30, 8)),
        DateTime(2026, 10, 31, 12),
      );
      expect(result.dueDateTime, DateTime(2026, 11, 1, 8));
    });

    test('keeps the reminders and stamps updatedAt', () {
      final task = Task(
        title: 'a',
        reminderMinutes: 15,
        dueDateTime: DateTime(2026, 10, 17, 18),
      );
      final result = movedToTomorrow(task, now);
      expect(result.reminderMinutes, 15);
      expect(result.updatedAt, now.toUtc());
    });
  });
}
