import '../models/task.dart';
import 'due_status.dart';
import 'task_sections.dart';

/// Open tasks the Focus tab offers: due today or earlier, soonest first.
/// Undated and upcoming tasks are left out; this is "what to do now".
List<Task> focusCandidates(List<Task> tasks, DateTime now) {
  final open = [
    for (final t in tasks)
      if (!t.isCompleted && _isDueByToday(t, now)) t,
  ];
  open.sort((a, b) {
    final byDue = a.dueDateTime!.compareTo(b.dueDateTime!);
    return byDue != 0 ? byDue : a.createdAt.compareTo(b.createdAt);
  });
  return open;
}

bool _isDueByToday(Task task, DateTime now) {
  final section = sectionFor(task, now);
  return section == TaskSection.overdue || section == TaskSection.today;
}

/// The task preselected on the Focus tab, from [focusCandidates]: the first
/// that is NOW or soon, else the most recently added one on Today, else the
/// oldest overdue one, else null.
Task? defaultFocusTaskFrom(List<Task> candidates, DateTime now) {
  for (final t in candidates) {
    final kind = DueStatus.of(t, now).kind;
    if (kind == DueKind.now || kind == DueKind.soon) return t;
  }
  final today = candidates.where(
    (t) => sectionFor(t, now) == TaskSection.today,
  );
  if (today.isNotEmpty) {
    return today.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
  }
  // Only overdue tasks are left; offer the one that has waited longest.
  return candidates.firstOrNull;
}

/// [defaultFocusTaskFrom] for a whole task list.
Task? defaultFocusTask(List<Task> tasks, DateTime now) =>
    defaultFocusTaskFrom(focusCandidates(tasks, now), now);
