import 'package:bloop/services/notif_service.dart';
import 'package:flutter/material.dart';
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
