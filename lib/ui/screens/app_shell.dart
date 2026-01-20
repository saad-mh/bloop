import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'completed_screen.dart';
import 'home_screen.dart';
import 'focus_screen.dart';
import 'settings_screen.dart';
import '../../providers/settings_provider.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

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
    FocusScreen(),
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
      extendBody: true,
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: _pages,
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: GNav(
          haptic: true,
          gap: 8,
          // rippleColor: settings.themeMode == ThemeMode.dark
          //     ? Colors.grey.shade800
          //     : Colors.grey.shade300,
          iconSize: 24,
          selectedIndex: _index,
          onTabChange: (i) {
            setState(() => _index = i);
            ref.read(settingsProvider.notifier).setLastTabIndex(i);
          },
          tabBackgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
          tabs: const [
            GButton(icon: Icons.list_alt, text: 'Active'),
            GButton(icon: Icons.checklist, text: 'Done'),
            GButton(icon: Icons.workspaces, text: 'Focus'),
            GButton(icon: Icons.settings, text: 'Settings'),
          ],
        ),
      ),
    );
  }
}
