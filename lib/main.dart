import 'package:bloop/services/notif_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'providers/settings_provider.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'ui/screens/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notifService = NotifService();
  await notifService.initNotification();
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: NotifService.focusSessionChannelId,
      channelName: NotifService.focusSessionChannelName,
      channelDescription: NotifService.focusSessionChannelDescription,
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
      iconData: const NotificationIconData(
        resType: ResourceType.mipmap,
        resPrefix: ResourcePrefix.ic,
        name: 'launcher',
      ),
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 60000,
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: false,
    ),
  );
  tz.initializeTimeZones();
  await StorageService.instance.init();
  await NotificationService.instance.init();
  runApp(const ProviderScope(child: BloopApp()));
}

class BloopApp extends ConsumerWidget {
  const BloopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final seed = Color(settings.seedColor);
    return MaterialApp(
      title: 'Bloop',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: settings.themeMode,
      home: const AppShell(),
    );
  }
}
