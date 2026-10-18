import 'dart:typed_data';

import 'package:bloop/main.dart';
import 'package:bloop/models/task.dart';
import 'package:bloop/providers/settings_provider.dart';
import 'package:bloop/providers/tab_provider.dart';
import 'package:bloop/providers/task_provider.dart';
import 'package:bloop/services/notif_service.dart';
import 'package:bloop/services/storage_service.dart';
import 'package:bloop/ui/screens/focus_controller.dart';
import 'package:bloop/ui/widgets/floating_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Keeps settings in memory: Hive's file writes never complete under the fake
/// clock widget tests run on.
class _Settings extends SettingsNotifier {
  _Settings({required bool v2, required int tab}) {
    state = state.copyWith(focusV2Enabled: v2, lastTabIndex: tab);
  }

  @override
  void setLastTabIndex(int index) {
    state = state.copyWith(lastTabIndex: index);
  }
}

class _Tasks extends TaskNotifier {
  _Tasks() {
    state = const AsyncData([]);
  }

  @override
  Future<void> load() async {}
}

/// The notification plugin isn't available under test.
class _QuietNotifs extends NotifService {
  @override
  Future<void> initNotification() async {}

  @override
  Future<void> scheduleAt({
    int id = 1,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {}

  @override
  Future<void> cancelNotification(int id) async {}

  @override
  Future<void> showFocusSessionNotification({
    required int id,
    required String title,
    required String body,
    required int remainingSeconds,
    required int totalSeconds,
    required bool isRunning,
  }) async {}
}

void main() {
  // Storage is held in memory: file I/O never completes under the fake clock
  // widget tests run on, and the controller saves its session as it goes.
  setUpAll(() async {
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(PriorityAdapter());
    Hive.registerAdapter(RecurrenceAdapter());
    await Hive.openBox<Task>(StorageService.tasksBoxName, bytes: Uint8List(0));
    await Hive.openBox<String>(StorageService.tagsBoxName, bytes: Uint8List(0));
    final settings = await Hive.openBox(
      StorageService.settingsBoxName,
      bytes: Uint8List(0),
    );
    // These tests are about the shell, not first-run onboarding.
    await settings.put(StorageService.onboardingCompleteKey, true);
  });

  tearDownAll(() async {
    await Hive.close();
  });

  late ProviderContainer container;

  Future<FocusController> pumpShell(
    WidgetTester tester, {
    required bool v2,
    int tab = focusTabIndex,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => _Settings(v2: v2, tab: tab)),
        taskListProvider.overrideWith((ref) => _Tasks()),
        focusControllerProvider.overrideWith(
          (ref) => FocusController(ref: ref, notifService: _QuietNotifs()),
        ),
      ],
    );
    addTearDown(container.dispose);
    final focus = container.read(focusControllerProvider)
      // The audio plugin isn't available under test.
      ..updateSessionPreferences(soundsEnabled: false);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const BloopApp()),
    );
    await tester.pumpAndSettle();
    return focus;
  }

  final newTask = find.byTooltip('New task');

  group('new screen on', () {
    testWidgets('the Focus tab shows the nav without New task', (tester) async {
      await pumpShell(tester, v2: true);

      expect(find.byType(FloatingNav), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(newTask, findsNothing);
    });

    testWidgets('the Tasks tab still has New task', (tester) async {
      await pumpShell(tester, v2: true, tab: tasksTabIndex);

      expect(newTask, findsOneWidget);
    });

    testWidgets('a running session hides the nav', (tester) async {
      final focus = await pumpShell(tester, v2: true);

      focus.startWithoutTask();
      await tester.pump();

      expect(find.byType(FloatingNav), findsNothing);
      expect(find.byTooltip('Minimise to Tasks'), findsOneWidget);
      expect(tester.takeException(), isNull);
      focus.endSession();
      await tester.pump();
    });

    testWidgets('minimising goes to Tasks, brings the nav back and keeps '
        'the timer running', (tester) async {
      final focus = await pumpShell(tester, v2: true);
      focus.startWithoutTask();
      await tester.pump();

      await tester.tap(find.byTooltip('Minimise to Tasks'));
      await tester.pumpAndSettle();

      expect(container.read(selectedTabProvider), tasksTabIndex);
      expect(find.byType(FloatingNav), findsOneWidget);
      expect(newTask, findsOneWidget);
      expect(focus.isRunning, isTrue);

      // Back on the Focus tab the running screen is still there. While a
      // session runs, the Focus segment shows the time left instead of its label.
      await tester.tap(
        find.descendant(
          of: find.byType(FloatingNav),
          matching: find.textContaining(':'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FloatingNav), findsNothing);
      expect(find.byTooltip('Minimise to Tasks'), findsOneWidget);
      focus.endSession();
      await tester.pump();
    });

    testWidgets('Android back minimises instead of leaving the app', (
      tester,
    ) async {
      final focus = await pumpShell(tester, v2: true);
      focus.startWithoutTask();
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(container.read(selectedTabProvider), tasksTabIndex);
      expect(focus.isRunning, isTrue);
      focus.endSession();
      await tester.pump();
    });

    testWidgets('Time\'s up also takes over the screen', (tester) async {
      final focus = await pumpShell(tester, v2: true);
      focus.startWithoutTask();
      focus.finishNowForTest();
      await tester.pump();

      expect(find.byType(FloatingNav), findsNothing);
      expect(find.text('Close'), findsOneWidget);
    });
  });

  group('new screen off', () {
    testWidgets('the Focus tab keeps New task and the old card', (
      tester,
    ) async {
      await pumpShell(tester, v2: false);

      expect(find.byType(FloatingNav), findsOneWidget);
      expect(newTask, findsOneWidget);
      expect(find.text('Focused today'), findsOneWidget);
      expect(find.text('Up next'.toUpperCase()), findsNothing);
    });
  });
}
