import '../models/recurrence.dart';
import '../models/task.dart';

class RecurrenceService {
  const RecurrenceService();

  Task applyNextOccurrence(Task task) {
    final nextDate = task.recurrence.next(task.dueDateTime);
    if (nextDate == null) return task.copyWith(isCompleted: true);

    return task.copyWith(
      isCompleted: false,
      completedAt: DateTime.now().toUtc(),
      dueDateTime: nextDate,
    );
  }
}
