import 'package:flutter_local_notifications/flutter_local_notifications.dart'
  as fln;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  final fln.FlutterLocalNotificationsPlugin _plugin =
      fln.FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final localTz = await _methodChannel.invokeMethod<String>('getLocalTimezone');
      if (localTz != null) {
        try {
          tz.setLocalLocation(tz.getLocation(localTz));
          // ignore: avoid_print
          print('NotificationService: timezone set to $localTz (tz.local=${tz.local.name})');
        } catch (inner) {
          // Try to normalize common legacy names (e.g. Asia/Calcutta -> Asia/Kolkata)
          String normalized = localTz;
          if (localTz.contains('Calcutta')) {
            normalized = localTz.replaceAll('Calcutta', 'Kolkata');
          }
          try {
            tz.setLocalLocation(tz.getLocation(normalized));
            // ignore: avoid_print
            print('NotificationService: timezone normalized from $localTz to $normalized (tz.local=${tz.local.name})');
          } catch (inner2) {
            // ignore: avoid_print
            print('NotificationService: failed to set timezone for $localTz and normalized $normalized: $inner2');
            // leave tz.local as default
          }
        }
      } else {
        // ignore: avoid_print
        print('NotificationService: platform did not return a timezone, using default tz.local=${tz.local.name}');
      }
    } catch (e) {
      // ignore: avoid_print
      print('NotificationService: failed to set local timezone via platform channel: $e');
    }

    const androidSettings =
        fln.AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = fln.DarwinInitializationSettings();
    const initSettings = fln.InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    await _plugin.resolvePlatformSpecificImplementation<
            fln.AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const fln.AndroidNotificationChannel(
      'bloop_tasks',
      'Task Reminders',
      description: 'Reminders for tasks',
      importance: fln.Importance.high,
    ));
  }

  Future<int?> scheduleReminder(Task task) async {
    // On Android we must ensure the app is allowed to schedule exact alarms
    if (Platform.isAndroid) {
      try {
        final can = await _methodChannel.invokeMethod<bool>('canScheduleExactAlarm');
        final canScheduleExact = (can == null) ? false : can;

        // Ensure notification permission is granted (Android 13+)
        final hasNotif = await _methodChannel.invokeMethod<bool>('hasNotificationPermission');
        if (hasNotif == null || hasNotif == false) {
          final granted = await _methodChannel.invokeMethod<bool>('requestNotificationPermission');
          if (granted == null || granted == false) {
            // ignore: avoid_print
            print('NotificationService: notification permission denied, returning null');
            // Open notification settings as fallback
            await _methodChannel.invokeMethod('openNotificationSettings');
            return null;
          }
        }

        // If the platform does not allow scheduling exact alarms, we will
        // fall back to a best-effort exact schedule mode instead of aborting.
        // This avoids blocking the user from receiving reminders when exact
        // alarms are restricted by the OS.
        if (!canScheduleExact) {
          // Log to help debugging on-device
          // ignore: avoid_print
          print('NotificationService: exact alarms not available, falling back to allowWhileIdle');
        }
      } catch (_) {
        // If platform channel fails, fall back to attempting to schedule.
      }
    }
    if (task.dueDateTime == null || task.reminderBefore == null) {
      // ignore: avoid_print
      print('NotificationService: missing due date or reminder, returning null');
      return null;
    }
    final scheduled = task.dueDateTime!.subtract(task.reminderBefore!);
    if (scheduled.isBefore(DateTime.now())) {
      // ignore: avoid_print
      print('NotificationService: scheduled time is in the past ($scheduled), returning null');
      return null;
    }

    final id = task.notificationId ?? task.id.hashCode;
    // Log computed times for debugging
    // ignore: avoid_print
    print('NotificationService: now=${DateTime.now().toIso8601String()} scheduledRaw=${scheduled.toIso8601String()} scheduledIsUtc=${scheduled.isUtc} tz.local=${tz.local.name}');
    final tzDateTime = tz.TZDateTime.from(scheduled, tz.local);

    // Decide schedule mode: prefer alarmClock when exact alarms are available,
    // otherwise fall back to exactAllowWhileIdle for a best-effort delivery.
    fln.AndroidScheduleMode scheduleMode = fln.AndroidScheduleMode.alarmClock;
    try {
      final can = await _methodChannel.invokeMethod<bool>('canScheduleExactAlarm');
      if (can == null || can == false) {
        scheduleMode = fln.AndroidScheduleMode.exactAllowWhileIdle;
      }
    } catch (_) {
      scheduleMode = fln.AndroidScheduleMode.exactAllowWhileIdle;
    }

    // Debug log
    // ignore: avoid_print
    print('NotificationService: scheduling id=$id at $tzDateTime using mode=$scheduleMode');

    await _plugin.zonedSchedule(
      id,
      task.title,
      task.notes ?? 'Task reminder',
      tzDateTime,
      const fln.NotificationDetails(
        android: fln.AndroidNotificationDetails(
          'bloop_tasks',
          'Task Reminders',
          channelDescription: 'Reminders for tasks',
          importance: fln.Importance.defaultImportance,
          priority: fln.Priority.defaultPriority,
        ),
        iOS: fln.DarwinNotificationDetails(),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          fln.UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: fln.DateTimeComponents.dateAndTime,
    );

    // Debug: list pending notification requests to confirm registration
    try {
      final pending = await _plugin.pendingNotificationRequests();
      // ignore: avoid_print
      print('NotificationService: pending requests=${pending.map((p) => '${p.id}:${p.title}').join(', ')}');
    } catch (e) {
      // ignore: avoid_print
      print('NotificationService: failed to list pending requests: $e');
    }

    return id;
  }

  /// Return list of pending notification requests (for debugging).
  Future<List<fln.PendingNotificationRequest>> getPendingRequests() async {
    try {
      return await _plugin.pendingNotificationRequests();
    } catch (_) {
      return <fln.PendingNotificationRequest>[];
    }
  }

  Future<void> cancel(int? id) async {
    if (id == null) return;
    await _plugin.cancel(id);
  }

  /// Debug helper: show an immediate test notification on the app channel.
  /// Use this to verify notification posting independent of AlarmManager.
  Future<void> showTestNotification() async {
    try {
      // Ensure channel exists with expected importance before showing.
      await _plugin.resolvePlatformSpecificImplementation<
              fln.AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const fln.AndroidNotificationChannel(
        'bloop_tasks',
        'Task Reminders',
        description: 'Reminders for tasks',
        importance: fln.Importance.high,
      ));

      // ignore: avoid_print
      print('NotificationService: ensured channel "bloop_tasks" exists');

      await _plugin.show(
        999999,
        'Bloop Test',
        'This is a test notification',
        const fln.NotificationDetails(
          android: fln.AndroidNotificationDetails(
            'bloop_tasks',
            'Task Reminders',
            channelDescription: 'Reminders for tasks',
            importance: fln.Importance.high,
            priority: fln.Priority.high,
          ),
          iOS: fln.DarwinNotificationDetails(),
        ),
      );
      // ignore: avoid_print
      print('NotificationService: test notification shown');
    } catch (e) {
      // ignore: avoid_print
      print('NotificationService: failed to show test notification: $e');
    }
  }

  static const MethodChannel _methodChannel = MethodChannel('bloop/permissions');

  Future<bool?> checkExactAlarmAllowed() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _methodChannel.invokeMethod<bool>('canScheduleExactAlarm');
    } catch (_) {
      return null;
    }
  }

  Future<bool?> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _methodChannel.invokeMethod<bool>('requestExactAlarm');
    } catch (_) {
      return null;
    }
  }

  Future<bool?> hasNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _methodChannel.invokeMethod<bool>('hasNotificationPermission');
    } catch (_) {
      return null;
    }
  }

  Future<bool?> requestNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _methodChannel.invokeMethod<bool>('requestNotificationPermission');
    } catch (_) {
      return null;
    }
  }

  Future<bool?> openNotificationSettings() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _methodChannel.invokeMethod<bool>('openNotificationSettings');
    } catch (_) {
      return null;
    }
  }
}
