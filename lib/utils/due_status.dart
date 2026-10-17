import '../models/task.dart';

/// How a task row presents its due time.
enum DueKind {
  /// No due date.
  anytime,

  /// Due on an earlier calendar day.
  late,

  /// Due time reached, no more than [DueStatus.nowWindow] ago.
  now,

  /// Due no more than [DueStatus.soonWindow] ahead.
  soon,

  /// Everything else with a due date.
  scheduled,
}

class DueStatus {
  const DueStatus(this.kind, {this.daysLate = 0, this.minutesAhead = 0});

  static const nowWindow = Duration(minutes: 30);
  static const soonWindow = Duration(minutes: 60);

  final DueKind kind;

  /// Whole calendar days past due. Only meaningful for [DueKind.late].
  final int daysLate;

  /// Minutes until due, rounded up. Only meaningful for [DueKind.soon].
  final int minutesAhead;

  /// Status of [task] as of [now].
  ///
  /// Lateness follows calendar days, matching [sectionFor]: a task due earlier
  /// today is not late, and an all-day task is never NOW or soon.
  static DueStatus of(Task task, DateTime now) {
    final due = task.dueDateTime?.toLocal();
    if (due == null) return const DueStatus(DueKind.anytime);

    final localNow = now.toLocal();
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final dueDay = DateTime(due.year, due.month, due.day);
    if (dueDay.isBefore(today)) {
      // Round, not truncate: the difference spans 23 or 25 hours over a DST
      // change.
      final days = (today.difference(dueDay).inHours / 24).round();
      return DueStatus(DueKind.late, daysLate: days);
    }
    if (task.allDay) return const DueStatus(DueKind.scheduled);

    final ahead = due.difference(localNow);
    if (!ahead.isNegative && ahead <= soonWindow) {
      if (ahead == Duration.zero) return const DueStatus(DueKind.now);
      return DueStatus(
        DueKind.soon,
        minutesAhead: (ahead.inSeconds / 60).ceil(),
      );
    }
    if (ahead.isNegative && -ahead <= nowWindow) {
      return const DueStatus(DueKind.now);
    }
    return const DueStatus(DueKind.scheduled);
  }
}

/// "1 day late" / "2 days late".
String lateLabel(int days) => days == 1 ? '1 day late' : '$days days late';
