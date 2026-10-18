import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'home_screen.dart';
import 'focus_screen.dart';
import 'task_editor_screen.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tab_provider.dart';
import '../../services/notification_service.dart';
import '../../services/storage_service.dart';
import '../widgets/floating_nav.dart';
import '../widgets/permission_prompt.dart';
import 'focus_controller.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  static const String _permissionsOnboardingKey =
      'permissionsOnboardingDone';
  bool _permissionFlowStarted = false;
  bool _waitingForReturn = false;
  int _permissionStepIndex = 0;
  final List<_PermissionStep> _permissionSteps = <_PermissionStep>[];

  /// One entry per tab, so the nav and the pages can't drift apart.
  static const _tabs = [
    (
      destination: FloatingNavDestination(
        icon: Icons.check_circle_outline,
        label: 'Tasks',
      ),
      page: HomeScreen(),
    ),
    (
      destination: FloatingNavDestination(icon: Icons.adjust, label: 'Focus'),
      page: FocusScreen(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    assert(_tabs.length == tabCount);
    WidgetsBinding.instance.addObserver(this);
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
    final shouldOpen = await showPermissionPrompt(
      context,
      kind: step.kind,
      step: _permissionStepIndex + 1,
      steps: _permissionSteps.length,
    );

    if (!mounted) return;

    if (!shouldOpen) {
      _waitingForReturn = false;
      await _advancePermissionFlow();
      return;
    }

    switch (step) {
      case _PermissionStep.notifications:
        // The system's own dialog, so there is no settings page to come back
        // from.
        await NotificationService.instance.requestNotificationPermission();
        if (!mounted) return;
        await _advancePermissionFlow();
        break;
      case _PermissionStep.exactAlarm:
        _waitingForReturn = true;
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


  void _selectTab(int i) {
    if (i == ref.read(selectedTabProvider)) return;
    HapticFeedback.selectionClick();
    ref.read(selectedTabProvider.notifier).select(i);
  }

  void _openNewTask() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TaskEditorScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final index = ref.watch(selectedTabProvider);
    final focusController = ref.watch(focusControllerProvider);
    final v2 = settings.focusV2Enabled;
    final onFocusTab = index == focusTabIndex;
    // The new Focus screen takes over while a session runs or is waiting for
    // an answer; back minimises it to Tasks instead of leaving the app.
    final v2Takeover =
        v2 &&
        onFocusTab &&
        (focusController.isSessionActive || focusController.isFinished);
    final isFullScreen = !v2 && focusController.isFullScreenActive;
    final pages = IndexedStack(
      index: index,
      children: [for (final tab in _tabs) tab.page],
    );
    return PopScope(
      canPop: !v2Takeover,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(selectedTabProvider.notifier).select(tasksTabIndex);
      },
      child: Scaffold(
        body: isFullScreen
            ? pages
            : FloatingNavLayer(
                showNav: !v2Takeover,
                nav: FloatingNav(
                  destinations: [for (final tab in _tabs) tab.destination],
                  selectedIndex: index,
                  onSelected: _selectTab,
                  onNewTask: _openNewTask,
                  // Nothing to add from the new Focus tab.
                  showNewTask: !(v2 && onFocusTab),
                ),
                // Top safe area only: the list runs behind the nav and scrim.
                child: SafeArea(bottom: false, child: pages),
              ),
      ),
    );
  }
}

enum _PermissionStep {
  notifications(PermissionKind.notifications),
  exactAlarm(PermissionKind.exactAlarm);

  const _PermissionStep(this.kind);

  final PermissionKind kind;
}
