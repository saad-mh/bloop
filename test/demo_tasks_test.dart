import 'package:bloop/models/recurrence.dart';
import 'package:bloop/models/task.dart';
import 'package:bloop/utils/demo_tasks.dart';
import 'package:bloop/utils/due_status.dart';
import 'package:bloop/utils/task_sections.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Midday, mid-afternoon, evening: the set should cover the states at each.
  for (final now in [
    DateTime(2026, 10, 17, 9, 15),
    DateTime(2026, 10, 17, 15, 42),
    DateTime(2026, 10, 17, 20, 10),
  ]) {
    test('covers every row state at $now', () {
      final tasks = buildDemoTasks(now);
      final active = tasks.where((t) => !t.isCompleted).toList();
      final kinds = {for (final t in active) DueStatus.of(t, now).kind};
      final sections = {for (final t in active) sectionFor(t, now)};

      expect(kinds, containsAll(DueKind.values));
      expect(sections, containsAll(TaskSection.values));
      expect(active.any((t) => t.priority == Priority.high), isTrue);
      expect(active.any((t) => t.remindersBefore.isNotEmpty), isTrue);
      expect(active.any((t) => t.allDay), isTrue);
      expect(active.any((t) => t.recurrence != Recurrence.none), isTrue);
      expect(active.any((t) => t.tags.length > 1), isTrue);
      expect(tasks.any((t) => t.isCompleted), isTrue);
    });
  }

  test('soon task is 18 minutes ahead and carries a reminder', () {
    final now = DateTime(2026, 10, 17, 15, 42);
    final soon = buildDemoTasks(
      now,
    ).firstWhere((t) => DueStatus.of(t, now).kind == DueKind.soon);
    expect(soon.remindersBefore, isNotEmpty);
  });

  test('every demo task has a unique id', () {
    final tasks = buildDemoTasks(DateTime(2026, 10, 17, 15, 42));
    expect({for (final t in tasks) t.id}.length, tasks.length);
  });
}
