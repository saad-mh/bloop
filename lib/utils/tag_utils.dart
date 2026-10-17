import '../models/task.dart';

/// Why a tag name was refused.
enum TagNameError {
  empty('Enter a name for the tag'),
  duplicate('A tag with that name already exists'),

  /// Storage threw; nothing was validated against.
  failed('Could not save the tag. Try again');

  const TagNameError(this.message);

  final String message;
}

/// Checks [raw] as a new tag name against the [existing] tags.
///
/// Names are compared trimmed and case-insensitively. When renaming, pass the
/// tag being renamed as [renaming] so it doesn't clash with itself, which also
/// lets "work" become "Work".
TagNameError? validateTagName(
  String raw,
  Iterable<String> existing, {
  String? renaming,
}) {
  final name = raw.trim();
  if (name.isEmpty) return TagNameError.empty;
  final key = name.toLowerCase();
  for (final other in existing) {
    if (other == renaming) continue;
    if (other.trim().toLowerCase() == key) return TagNameError.duplicate;
  }
  return null;
}

/// How many not-yet-completed tasks carry each tag. Tags with no open task
/// are absent from the map.
Map<String, int> openTaskCounts(Iterable<Task> tasks) {
  final counts = <String, int>{};
  for (final task in tasks) {
    if (task.isCompleted) continue;
    for (final tag in task.tags.toSet()) {
      counts[tag] = (counts[tag] ?? 0) + 1;
    }
  }
  return counts;
}

/// How many tasks carry [tag], completed ones included (`total`, what a
/// delete or rename touches), and how many of those are still open. Both come
/// from one pass so they always agree.
({int total, int open}) tagUsage(Iterable<Task> tasks, String tag) {
  var total = 0;
  var open = 0;
  for (final task in tasks) {
    if (!task.tags.contains(tag)) continue;
    total++;
    if (!task.isCompleted) open++;
  }
  return (total: total, open: open);
}
