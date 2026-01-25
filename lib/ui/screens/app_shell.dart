import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'completed_screen.dart';
import 'home_screen.dart';
import 'focus_screen.dart';
import 'settings_screen.dart';
import '../../providers/settings_provider.dart';
import '../../services/notification_service.dart';
import '../../services/storage_service.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

import 'focus_controller.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  int _index = 0;

  static const String _permissionsOnboardingKey =
      'permissionsOnboardingDone';
  bool _permissionFlowStarted = false;
  bool _waitingForReturn = false;
  int _permissionStepIndex = 0;
  final List<_PermissionStep> _permissionSteps = <_PermissionStep>[];

  final _pages = const [
    HomeScreen(),
    CompletedScreen(),
    FocusScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final settings = ref.read(settingsProvider);
    _index = settings.lastTabIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runFirstLaunchPermissionFlow();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForReturn) {
      _waitingForReturn = false;
      _advancePermissionFlow();
    }
    super.didChangeAppLifecycleState(state);
  }

  Future<void> _runFirstLaunchPermissionFlow() async {
    if (_permissionFlowStarted || !mounted) return;

    final box = Hive.box(StorageService.settingsBoxName);
    final alreadyDone = box.get(_permissionsOnboardingKey) as bool? ?? false;
    if (alreadyDone) return;

    _permissionSteps.clear();

    if (Platform.isAndroid) {
      final hasNotifications =
          await NotificationService.instance.hasNotificationPermission();
      if (hasNotifications != true) {
        _permissionSteps.add(_PermissionStep.notifications);
      }

      final canExact =
          await NotificationService.instance.checkExactAlarmAllowed();
      if (canExact != true) {
        _permissionSteps.add(_PermissionStep.exactAlarm);
      }
    }

    if (_permissionSteps.isEmpty) {
      await box.put(_permissionsOnboardingKey, true);
      return;
    }

    _permissionFlowStarted = true;
    _permissionStepIndex = 0;
    await _openCurrentPermissionStep();
  }

  Future<void> _openCurrentPermissionStep() async {
    if (!mounted) return;
    if (_permissionStepIndex >= _permissionSteps.length) {
      await _completePermissionFlow();
      return;
    }

    final step = _permissionSteps[_permissionStepIndex];
    final dialogCopy = _dialogCopyForStep(step);
    final shouldOpen = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(dialogCopy.title),
        content: Text(dialogCopy.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(dialogCopy.confirmLabel),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (shouldOpen != true) {
      _waitingForReturn = false;
      await _advancePermissionFlow();
      return;
    }

    _waitingForReturn = true;
    switch (step) {
      case _PermissionStep.notifications:
        await NotificationService.instance.openNotificationSettings();
        break;
      case _PermissionStep.exactAlarm:
        await NotificationService.instance.requestExactAlarmPermission();
        break;
    }
  }

  Future<void> _advancePermissionFlow() async {
    if (!mounted || !_permissionFlowStarted) return;
    _permissionStepIndex += 1;
    await _openCurrentPermissionStep();
  }

  Future<void> _completePermissionFlow() async {
    final box = Hive.box(StorageService.settingsBoxName);
    await box.put(_permissionsOnboardingKey, true);
    _permissionFlowStarted = false;
  }

  _PermissionDialogCopy _dialogCopyForStep(_PermissionStep step) {
    switch (step) {
      case _PermissionStep.notifications:
        return const _PermissionDialogCopy(
          title: 'Enable notifications',
          message:
              'Bloop needs notification access so reminders can alert you on time. We will open system settings to turn it on.',
          confirmLabel: 'Open settings',
        );
      case _PermissionStep.exactAlarm:
        return const _PermissionDialogCopy(
          title: 'Allow exact alarms',
          message:
              'Exact alarms let Bloop deliver reminders at the precise time. We will open system settings to enable it.',
          confirmLabel: 'Open settings',
        );
    }
  }
  @override
  Widget build(BuildContext context) {
    ref.watch(settingsProvider);
    final focusController = ref.watch(focusControllerProvider);
    final isFullScreen = focusController.isFullScreenActive;
    return Scaffold(
      extendBody: true,
      body: isFullScreen
          ? IndexedStack(
              index: _index,
              children: _pages,
            )
          : SafeArea(
              child: IndexedStack(
                index: _index,
                children: _pages,
              ),
            ),
      bottomNavigationBar: isFullScreen
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: GNav(
                  haptic: true,
                  gap: 6,
                  // rippleColor: settings.themeMode == ThemeMode.dark
                  //     ? Colors.grey.shade800
                  //     : Colors.grey.shade300,
                  iconSize: 24,
                  textSize: 12,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                  tabMargin: const EdgeInsets.symmetric(horizontal: 4),
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  selectedIndex: _index,
                  onTabChange: (i) {
                    setState(() => _index = i);
                    ref.read(settingsProvider.notifier).setLastTabIndex(i);
                  },
                  tabBackgroundColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.1),
                  tabs: const [
                    GButton(icon: Icons.task_alt, text: 'Tasks'),
                    GButton(icon: Icons.done_all, text: 'Completed'),
                    GButton(icon: Icons.workspaces, text: 'Focus'),
                    GButton(icon: Icons.settings_suggest, text: 'Preferences'),
                  ],
                ),
              ),
            ),
    );
  }
}

enum _PermissionStep {
  notifications,
  exactAlarm,
}

class _PermissionDialogCopy {
  const _PermissionDialogCopy({
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;
}
