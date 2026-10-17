import '../models/task.dart';

/// [task] pushed back by [by], for the row's Snooze action.
///
/// The hour counts from the later of the due time and [now], so snoozing a
/// late task lands an hour from now rather than still in the past, and
/// snoozing one due this evening moves it on from then. An undated or all-day
/// task has no time of day to push, so it becomes a timed task [by] from now.
Task snoozed(
  Task task,
  DateTime now, {
  Duration by = const Duration(hours: 1),
}) {
  final localNow = now.toLocal();
  final due = task.dueDateTime?.toLocal();
  final timed = due != null && !task.allDay;
  final base = timed && due.isAfter(localNow) ? due : localNow;
  return task.copyWith(
    dueDateTime: base.add(by),
    allDay: false,
    updatedAt: now.toUtc(),
  );
}

/// [task] moved to tomorrow, for the row's Tomorrow action.
///
/// A timed task keeps its time of day. An undated or all-day task becomes an
/// all-day task tomorrow. Built from calendar fields rather than a 24 hour
/// offset so a daylight saving change doesn't shift the time.
Task movedToTomorrow(Task task, DateTime now) {
  final localNow = now.toLocal();
  final due = task.dueDateTime?.toLocal();
  final timed = due != null && !task.allDay;
  return task.copyWith(
    dueDateTime: timed
        ? DateTime(
            localNow.year,
            localNow.month,
            localNow.day + 1,
            due.hour,
            due.minute,
          )
        : DateTime(localNow.year, localNow.month, localNow.day + 1),
    allDay: !timed,
    updatedAt: now.toUtc(),
  );
}
