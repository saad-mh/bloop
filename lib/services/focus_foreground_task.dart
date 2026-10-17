import 'dart:async';

import 'dart:isolate';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notif_service.dart';

class FocusSessionPrefs {
  static const String sessionTypeKey = 'focus.sessionType';
  static const String sessionStartKey = 'focus.sessionStartTimestampUtc';
  static const String plannedDurationKey = 'focus.plannedDurationSeconds';
  static const String sessionIndexKey = 'focus.sessionIndex';
  static const String isRunningKey = 'focus.isRunning';
  static const String isActiveKey = 'focus.isActive';
  static const String totalSessionsKey = 'focus.totalSessions';
  static const String focusNotificationsEnabledKey =
      'focusSessionNotificationsEnabled';

  static const int focusNotificationId = 90002;

  static Future<void> writeSession({
    required String sessionType,
    required DateTime sessionStartUtc,
    required int plannedDurationSeconds,
    required int sessionIndex,
    required int totalSessions,
    required bool isRunning,
    required bool isActive,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(sessionTypeKey, sessionType);
    await prefs.setInt(sessionStartKey, sessionStartUtc.millisecondsSinceEpoch);
    await prefs.setInt(plannedDurationKey, plannedDurationSeconds);
    await prefs.setInt(sessionIndexKey, sessionIndex);
    await prefs.setInt(totalSessionsKey, totalSessions);
    await prefs.setBool(isRunningKey, isRunning);
    await prefs.setBool(isActiveKey, isActive);
  }

  static Future<void> setFocusNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(focusNotificationsEnabledKey, enabled);
  }

  static Future<bool> isFocusNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(focusNotificationsEnabledKey) ?? false;
  }

  static Future<FocusSessionSnapshot?> readSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionType = prefs.getString(sessionTypeKey);
    final startMillis = prefs.getInt(sessionStartKey);
    final plannedDurationSeconds = prefs.getInt(plannedDurationKey);
    if (sessionType == null || startMillis == null || plannedDurationSeconds == null) {
      return null;
    }
    final sessionIndex = prefs.getInt(sessionIndexKey) ?? 1;
    final totalSessions = prefs.getInt(totalSessionsKey) ?? 1;
    final isRunning = prefs.getBool(isRunningKey) ?? false;
    final isActive = prefs.getBool(isActiveKey) ?? false;
    return FocusSessionSnapshot(
      sessionType: sessionType,
      sessionStartUtc:
          DateTime.fromMillisecondsSinceEpoch(startMillis, isUtc: true),
      plannedDurationSeconds: plannedDurationSeconds,
      sessionIndex: sessionIndex,
      totalSessions: totalSessions,
      isRunning: isRunning,
      isActive: isActive,
    );
  }
}

class FocusSessionSnapshot {
  const FocusSessionSnapshot({
    required this.sessionType,
    required this.sessionStartUtc,
    required this.plannedDurationSeconds,
    required this.sessionIndex,
    required this.totalSessions,
    required this.isRunning,
    required this.isActive,
  });

  final String sessionType;
  final DateTime sessionStartUtc;
  final int plannedDurationSeconds;
  final int sessionIndex;
  final int totalSessions;
  final bool isRunning;
  final bool isActive;

  String get sessionLabel {
    switch (sessionType) {
      case 'shortBreak':
        return 'Short break';
      case 'longBreak':
        return 'Long break';
      case 'focus':
      default:
        return 'Focus';
    }
  }

  String get secondaryLine {
    switch (sessionType) {
      case 'shortBreak':
        return 'Break time • relax';
      case 'longBreak':
        return 'Break time • recharge';
      case 'focus':
      default:
        return 'Session $sessionIndex of $totalSessions • Deep Focus Session';
    }
  }
}

@pragma('vm:entry-point')
void startFocusForegroundTask() {
  FlutterForegroundTask.setTaskHandler(FocusForegroundTaskHandler());
}

class FocusForegroundTaskHandler extends TaskHandler {
  FlutterLocalNotificationsPlugin? _plugin;

  @override
  void onStart(DateTime timestamp, SendPort? sendPort) {
    _initNotifications();
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) {
    _updateNotification();
  }

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) {}

  Future<void> _initNotifications() async {
    _plugin = FlutterLocalNotificationsPlugin();
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin?.initialize(initSettings);
    await _plugin
        ?.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
      NotifService.focusSessionChannelId,
      NotifService.focusSessionChannelName,
      description: NotifService.focusSessionChannelDescription,
      importance: Importance.low,
    ));
  }

  Future<void> _updateNotification() async {
    final enabled = await FocusSessionPrefs.isFocusNotificationsEnabled();
    final snapshot = await FocusSessionPrefs.readSession();
    if (!enabled || snapshot == null || !snapshot.isActive) {
      await _plugin?.cancel(FocusSessionPrefs.focusNotificationId);
      FlutterForegroundTask.stopService();
      return;
    }

    final nowUtc = DateTime.now().toUtc();
    final remainingSeconds = snapshot.isRunning
        ? snapshot.plannedDurationSeconds -
            nowUtc.difference(snapshot.sessionStartUtc).inSeconds
        : snapshot.plannedDurationSeconds;

    if (remainingSeconds <= 0) {
      await _plugin?.cancel(FocusSessionPrefs.focusNotificationId);
      FlutterForegroundTask.stopService();
      return;
    }

    final minutesLeft = (remainingSeconds / 60).ceil().clamp(0, 9999);
    final title = '${snapshot.sessionLabel} • $minutesLeft min left';
    final body = snapshot.secondaryLine;

    final totalSeconds = snapshot.plannedDurationSeconds <= 0
        ? 1
        : snapshot.plannedDurationSeconds;
    final progress = (totalSeconds - remainingSeconds).clamp(0, totalSeconds);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        NotifService.focusSessionChannelId,
        NotifService.focusSessionChannelName,
        channelDescription: NotifService.focusSessionChannelDescription,
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
        onlyAlertOnce: true,
        ongoing: true,
        autoCancel: false,
        showProgress: true,
        maxProgress: totalSeconds,
        progress: progress,
        actions: [
          AndroidNotificationAction(
            NotifService.focusSessionToggleAction,
            snapshot.isRunning ? 'Pause' : 'Continue',
            showsUserInterface: true,
            cancelNotification: false,
          ),
          const AndroidNotificationAction(
            NotifService.focusSessionSkipAction,
            'Skip session',
            showsUserInterface: true,
            cancelNotification: false,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: false,
        presentSound: false,
      ),
    );

    await _plugin?.show(
      FocusSessionPrefs.focusNotificationId,
      title,
      body,
      details,
      payload: NotifService.focusSessionPayload,
    );
  }
}
