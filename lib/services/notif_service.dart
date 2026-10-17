import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

enum FocusSessionAction {
  toggle,
  skip,
}

class NotifService {
  final notifPlugin = FlutterLocalNotificationsPlugin();

  static const String focusSessionChannelId = 'focus_session';
  static const String focusSessionChannelName = 'Focus Session';
  static const String focusSessionChannelDescription =
      'Persistent notifications for active focus sessions';
  static const String focusSessionPayload = 'focus_session';
  static const String focusSessionToggleAction = 'focus_toggle';
  static const String focusSessionSkipAction = 'focus_skip';

  final StreamController<FocusSessionAction> _focusActionController =
      StreamController<FocusSessionAction>.broadcast();

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Stream<FocusSessionAction> get focusSessionActions =>
      _focusActionController.stream;

// Init
  Future<void> initNotification() async {
    if (_isInitialized) return;

    // timezone handling
    tz.initializeTimeZones();
    final rawTimeZone = await FlutterTimezone.getLocalTimezone();
    final tzString = RegExp(r'([A-Za-z_]+\/[A-Za-z_]+)').firstMatch(rawTimeZone.toString())?.group(0) ?? 'UTC';

    try {
      tz.setLocalLocation(tz.getLocation(tzString));
    } catch (e) {
      // ignore: avoid_print
      print('NotifService: tz.getLocation failed for "$tzString": $e — falling back to UTC');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // prep Android settings
    const initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // prep iOS settings
    const initSettingsiOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsiOS,
    );

    await notifPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Use the same plugin instance to create the channel so platform
    // implementation sees the channel metadata we expect.
    await notifPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
      const AndroidNotificationChannel(
        "task_reminder_b",
        "Task Reminder B",
        description: "Reminder notifications for tasks v2",
        importance: Importance.max,
      ),
    );
    await notifPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
      const AndroidNotificationChannel(
        focusSessionChannelId,
        focusSessionChannelName,
        description: focusSessionChannelDescription,
        importance: Importance.low,
      ),
    );
    _isInitialized = true;
  }

  NotificationDetails notificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        "task_reminder_b", 
        "Task Reminder B",
        channelDescription: "Reminder notifications for tasks v2",
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(

      )
    );
  }

  Future<void> showNotification({int id = 0, String? title, String? body}) async {
    // Ensure notification details are provided (avoids plugin NPE when Android
    // specifics are missing). Use our configured channel/details helper.
    await notifPlugin.show(
      id,
      title,
      body,
      notificationDetails(),
    );
  }

  /*
  
  hour = 0-23
  minute = 0-59
  weekday = 1-7 (Mon-Sun)

  */

  Future<void> scheduleNotification({
    int id = 1,
    required String title,
    required String body,
    required int minute,
    required int hour,
    int? day,
    int? month,
    int? year,
  }) async{
    final now = tz.TZDateTime.now(tz.local);
    // var scheduledDate = tz.TZDateTime(
    //   tz.local, 
    //   year ?? now.year,
    //   month ?? now.month, 
    //   day ?? now.day, 
    //   hour, 
    //   minute,
    //   );

    var scheduledDate = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 3));
    
    final tz.TZDateTime scheduledFor = scheduledDate.isBefore(now)
        ? scheduledDate.add(const Duration(days: 1))
        : scheduledDate;

    // Prefer a more exact schedule mode to improve delivery reliability.
    try {
      await notifPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledFor,
        notificationDetails(),
        // Android: use alarmClock mode for reliable delivery when possible
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      // Debug: list pending notification requests to confirm registration
      try {
        final pending = await notifPlugin.pendingNotificationRequests();
        // ignore: avoid_print
        print('NotifService: pending requests=${pending.map((p) => '${p.id}:${p.title}').join(', ')}');
      } catch (e) {
        // ignore: avoid_print
        print('NotifService: failed to list pending requests: $e');
      }

      // ignore: avoid_print
      print('NotifService: scheduled notification id=$id for $scheduledFor (now: $now)');
    } catch (e, st) {
      // ignore: avoid_print
      print('NotifService: failed to schedule notification: $e\n$st');
    }
  }

  Future<void> scheduleAt({
    int id = 1,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    final localTime = scheduledTime.isUtc
        ? scheduledTime.toLocal()
        : scheduledTime;
    final scheduledFor = tz.TZDateTime.from(localTime, tz.local);

    try {
      await notifPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledFor.isBefore(now)
            ? scheduledFor.add(const Duration(seconds: 1))
            : scheduledFor,
        notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('NotifService: failed to scheduleAt notification: $e\n$st');
    }
  }

  Future<void> cancelNotification(int id) async {
    await notifPlugin.cancel(id);
  }

  Future<void> showFocusSessionNotification({
    required int id,
    required String title,
    required String body,
    required int remainingSeconds,
    required int totalSeconds,
    required bool isRunning,
  }) async {
    final clampedTotal = totalSeconds <= 0 ? 1 : totalSeconds;
    final clampedRemaining = remainingSeconds < 0 ? 0 : remainingSeconds;
    final progress = (clampedTotal - clampedRemaining).clamp(0, clampedTotal);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        focusSessionChannelId,
        focusSessionChannelName,
        channelDescription: focusSessionChannelDescription,
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
        onlyAlertOnce: true,
        ongoing: true,
        autoCancel: false,
        showProgress: true,
        maxProgress: clampedTotal,
        progress: progress,
        actions: [
          AndroidNotificationAction(
            focusSessionToggleAction,
            isRunning ? 'Pause' : 'Continue',
            showsUserInterface: true,
            cancelNotification: false,
          ),
          const AndroidNotificationAction(
            focusSessionSkipAction,
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

    await notifPlugin.show(
      id,
      title,
      body,
      details,
      payload: focusSessionPayload,
    );
  }

  Future<void> cancelAllNotifications() async {
    await notifPlugin.cancelAll();
  }

  void _handleNotificationResponse(NotificationResponse response) {
    if (response.actionId == focusSessionToggleAction) {
      _focusActionController.add(FocusSessionAction.toggle);
      return;
    }
    if (response.actionId == focusSessionSkipAction) {
      _focusActionController.add(FocusSessionAction.skip);
      return;
    }
  }

}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  //
}