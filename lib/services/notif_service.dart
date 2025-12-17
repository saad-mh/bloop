import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotifService {
  final notifPlugin = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

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

    await notifPlugin.initialize(initSettings);

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

  Future<void> cancelNotification(int id) async {
    await notifPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await notifPlugin.cancelAll();
  }

}