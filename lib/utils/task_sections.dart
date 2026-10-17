import '../models/task.dart';

/// Home list sections, in display order.
enum TaskSection {
  overdue('Overdue'),
  today('Today'),
  upcoming('Upcoming'),
  whenever('Whenever');

  const TaskSection(this.label);

  final String label;
}

class TaskGroup {
  const TaskGroup(this.section, this.tasks);

  final TaskSection section;
  final List<Task> tasks;
}

/// Section [task] belongs to as of [now].
///
/// Days are compared by calendar date, so a task due earlier today stays in
/// Today until midnight and an all-day task is never late on its own day.
TaskSection sectionFor(Task task, DateTime now) {
  final due = task.dueDateTime?.toLocal();
  if (due == null) return TaskSection.whenever;

  final today = DateTime(now.year, now.month, now.day);
  final dueDay = DateTime(due.year, due.month, due.day);
  if (dueDay.isBefore(today)) return TaskSection.overdue;
  if (dueDay.isAfter(today)) return TaskSection.upcoming;
  return TaskSection.today;
}

/// Splits [tasks] into sections, keeping their order within each one. Sections
/// with no tasks are left out.
List<TaskGroup> groupTasksBySection(List<Task> tasks, DateTime now) {
  final buckets = {for (final s in TaskSection.values) s: <Task>[]};
  for (final task in tasks) {
    buckets[sectionFor(task, now)]!.add(task);
  }
  return [
    for (final section in TaskSection.values)
      if (buckets[section]!.isNotEmpty) TaskGroup(section, buckets[section]!),
  ];
}
