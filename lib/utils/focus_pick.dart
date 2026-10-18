import '../models/task.dart';
import 'due_status.dart';
import 'task_sections.dart';

/// Open tasks the Focus tab offers: due today or earlier, soonest first.
/// Undated and upcoming tasks are left out; this is "what to do now".
List<Task> focusCandidates(List<Task> tasks, DateTime now) {
  final open = [
    for (final t in tasks)
      if (!t.isCompleted &&
          (sectionFor(t, now) == TaskSection.overdue ||
              sectionFor(t, now) == TaskSection.today))
        t,
  ];
  open.sort((a, b) {
    final byDue = a.dueDateTime!.compareTo(b.dueDateTime!);
    return byDue != 0 ? byDue : a.createdAt.compareTo(b.createdAt);
  });
  return open;
}

/// The task preselected on the Focus tab: the first that is NOW or soon, else
/// the most recently added one on Today, else null.
Task? defaultFocusTask(List<Task> tasks, DateTime now) {
  final candidates = focusCandidates(tasks, now);
  for (final t in candidates) {
    final kind = DueStatus.of(t, now).kind;
    if (kind == DueKind.now || kind == DueKind.soon) return t;
  }
  final today = candidates.where(
    (t) => sectionFor(t, now) == TaskSection.today,
  );
  if (today.isEmpty) return null;
  return today.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
}
