import 'package:bloop/services/notif_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'completed_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'tags_screen.dart';
import '../../providers/settings_provider.dart';
import 'package:flutter/foundation.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  final _pages = const [
    HomeScreen(),
    CompletedScreen(),
    TagsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _index = settings.lastTabIndex;
  }
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      appBar: kDebugMode
          ? AppBar(
              title: const Text(''),
              actions: [
                TextButton(onPressed: () {
                  NotifService().showNotification(
                      id: 10,
                      title: 'Test Notification',
                      body: 'Test Notif v2!'
                  );
                }, child: const Text('Test Notification')),
                TextButton(onPressed: () {
                  NotifService().scheduleNotification(
                      id: 10,
                      title: 'Test Notification',
                      body: 'Test Notif v2!',
                      hour: tz.TZDateTime.now(tz.local).hour,
                      minute: tz.TZDateTime.now(tz.local).minute,
                  );
                }, child: const Text('Schedule Notif'))
              ],
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          ref.read(settingsProvider.notifier).setLastTabIndex(i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Active'),
          NavigationDestination(icon: Icon(Icons.checklist), label: 'Done'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
