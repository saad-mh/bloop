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

  Future<List<int>?> addOrUpdate(Task task) async {
    try {
      final current = _storage.getById(task.id);
      final currentIds = current?.notificationIds ??
          (current?.notificationId != null ? [current!.notificationId!] : null);
      await _notifications.cancelMany(currentIds);
      // Debug: log scheduling attempt
      // ignore: avoid_print
      // print('TaskNotifier: scheduling reminder for task=${task.id} title=${task.title}');
      final newIds = await _notifications.scheduleReminders(task);
      // ignore: avoid_print
      // print('TaskNotifier: schedule result ids=$newIds');
      final toSave = task.copyWith(
        notificationIds: newIds ?? task.notificationIds,
        notificationId: newIds != null && newIds.isNotEmpty
            ? newIds.first
            : task.notificationId,
      );
      await _storage.upsert(toSave);
      await load();
      return newIds;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> toggleComplete(Task task, {bool? value}) async {
    try {
      final targetValue = value ?? !task.isCompleted;
      if (targetValue && task.recurrence != Recurrence.none) {
        await _notifications.cancelMany(
          task.notificationIds ?? (task.notificationId != null ? [task.notificationId!] : null),
        );
        final next = _recurrence.applyNextOccurrence(task);
        final newIds = await _notifications.scheduleReminders(next);
        await _storage.upsert(next.copyWith(
          notificationIds: newIds,
          notificationId: newIds != null && newIds.isNotEmpty ? newIds.first : null,
        ));
      } else {
        await _storage.toggleComplete(task.id, value: targetValue);
        if (targetValue) {
          await _notifications.cancelMany(
            task.notificationIds ??
                (task.notificationId != null ? [task.notificationId!] : null),
          );
        }
      }
      await load();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> delete(Task task) async {
    try {
      await _notifications.cancelMany(
        task.notificationIds ?? (task.notificationId != null ? [task.notificationId!] : null),
      );
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

  Future<void> clearAll() async {
    try {
      final tasks = _storage.getAll();
      for (final task in tasks) {
        await _notifications.cancelMany(
          task.notificationIds ??
              (task.notificationId != null ? [task.notificationId!] : null),
        );
      }
      await _storage.clearAllTasks();
      await load();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addDemoTasks() async {
    try {
      final now = DateTime.now();
      final todayMorning = DateTime(now.year, now.month, now.day, 9, 0);
      final todayEvening = DateTime(now.year, now.month, now.day, 18, 0);

      final demoTasks = <Task>[
        Task(
          title: 'Submit report',
          notes: 'Send weekly report to the team',
          dueDateTime: now.subtract(const Duration(days: 1, hours: 2)),
          priority: Priority.high,
        ),
        Task(
          title: 'Call dentist',
          dueDateTime: now.subtract(const Duration(days: 2)),
          priority: Priority.medium,
        ),
        Task(
          title: 'Standup prep',
          dueDateTime: todayMorning.add(const Duration(hours: 1)),
          priority: Priority.high,
        ),
        Task(
          title: 'Grocery run',
          dueDateTime: todayEvening,
          priority: Priority.low,
        ),
        Task(
          title: 'Plan sprint',
          dueDateTime: now.add(const Duration(days: 1, hours: 3)),
          priority: Priority.medium,
        ),
        Task(
          title: 'Book flights',
          dueDateTime: now.add(const Duration(days: 7, hours: 2)),
          priority: Priority.low,
        ),
        Task(
          title: 'Annual review',
          dueDateTime: now.add(const Duration(days: 30)),
          priority: Priority.high,
        ),
      ];

      for (final task in demoTasks) {
        await addOrUpdate(task);
      }
      await load();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  String exportJson() => _storage.exportToJson();
}
