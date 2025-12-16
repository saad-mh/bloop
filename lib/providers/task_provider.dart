import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../models/recurrence.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/recurrence_service.dart';

final taskListProvider =
    StateNotifierProvider<TaskNotifier, AsyncValue<List<Task>>>((ref) {
  return TaskNotifier();
});

final activeTasksProvider = Provider<AsyncValue<List<Task>>>((ref) {
  final tasks = ref.watch(taskListProvider);
  return tasks.whenData(
    (data) => data.where((t) => !t.isCompleted).toList()
      ..sort(_sortByDatePriority),
  );
});

final completedTasksProvider = Provider<AsyncValue<List<Task>>>((ref) {
  final tasks = ref.watch(taskListProvider);
  return tasks.whenData(
    (data) => data.where((t) => t.isCompleted).toList()
      ..sort((a, b) => (b.completedAt ?? b.createdAt)
          .compareTo(a.completedAt ?? a.createdAt)),
  );
});

int _sortByDatePriority(Task a, Task b) {
  // Primary: due date, then priority, then createdAt
  final dateA = a.dueDateTime;
  final dateB = b.dueDateTime;
  if (dateA != null && dateB != null) {
    final cmp = dateA.compareTo(dateB);
    if (cmp != 0) return cmp;
  } else if (dateA != null) {
    return -1;
  } else if (dateB != null) {
    return 1;
  }
  final priorityCmp = b.priority.index.compareTo(a.priority.index);
  if (priorityCmp != 0) return priorityCmp;
  return a.createdAt.compareTo(b.createdAt);
}

class TaskNotifier extends StateNotifier<AsyncValue<List<Task>>> {
  TaskNotifier() : super(const AsyncValue.loading()) {
    load();
  }
  final _storage = StorageService.instance;
  final _notifications = NotificationService.instance;
  final _recurrence = const RecurrenceService();

  Future<void> load() async {
    try {
      final tasks = _storage.getAll();
      state = AsyncValue.data(tasks);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<int?> addOrUpdate(Task task) async {
    try {
      final current = _storage.getById(task.id);
      if (current?.notificationId != null) {
        await _notifications.cancel(current!.notificationId);
      }
      // Debug: log scheduling attempt
      // ignore: avoid_print
      print('TaskNotifier: scheduling reminder for task=${task.id} title=${task.title}');
      final newId = await _notifications.scheduleReminder(task);
      // ignore: avoid_print
      print('TaskNotifier: schedule result id=$newId');
      final toSave = task.copyWith(notificationId: newId ?? task.notificationId);
      await _storage.upsert(toSave);
      await load();
      return newId;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> toggleComplete(Task task, {bool? value}) async {
    try {
      final targetValue = value ?? !task.isCompleted;
      if (targetValue && task.recurrence != Recurrence.none) {
        await _notifications.cancel(task.notificationId);
        final next = _recurrence.applyNextOccurrence(task);
        final newId = await _notifications.scheduleReminder(next);
        await _storage.upsert(next.copyWith(notificationId: newId));
      } else {
        await _storage.toggleComplete(task.id, value: targetValue);
        if (targetValue) {
          await _notifications.cancel(task.notificationId);
        }
      }
      await load();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> delete(Task task) async {
    try {
      await _notifications.cancel(task.notificationId);
      await _storage.delete(task.id);
      await load();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> importJson(String json) async {
    try {
      await _storage.importFromJson(json);
      await load();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  String exportJson() => _storage.exportToJson();
}
