import 'dart:io';

import 'package:bloop/models/task.dart';
import 'package:bloop/providers/settings_provider.dart';
import 'package:bloop/providers/tab_provider.dart';
import 'package:bloop/providers/task_provider.dart';
import 'package:bloop/services/storage_service.dart';
import 'package:bloop/ui/screens/focus_controller.dart';
import 'package:bloop/ui/screens/focus_v2_widgets.dart';
import 'package:bloop/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Keeps the tab choice in memory: Hive's file writes never complete under
/// the fake clock widget tests run on.
class _FakeSettings extends SettingsNotifier {
  @override
  void setLastTabIndex(int index) {
    state = state.copyWith(lastTabIndex: index);
  }
}

class _FakeTasks extends TaskNotifier {
  _FakeTasks(List<Task> tasks) {
    state = AsyncData(tasks);
  }

  @override
  Future<void> load() async {}
}

/// Stands in for the real controller, which needs the audio and notification
/// plugins.
class _FakeFocus extends ChangeNotifier implements FocusController {
  bool active = false;
  bool running = false;
  bool finished = false;
  String? task;
  String? id;
  Duration left = const Duration(minutes: 25);
  Duration length = const Duration(minutes: 25);
  Duration? focused;

  final started = <String>[];
  var startedFree = 0;
  var ended = 0;
  var completed = 0;
  var paused = 0;
  var resumed = 0;
  var keptGoing = 0;
  var dismissed = 0;

  @override
  bool get isInitializing => false;
  @override
  bool get isSessionActive => active;
  @override
  bool get isRunning => running;
  @override
  bool get isFinished => finished;
  @override
  String? get taskTitle => task;
  @override
  String? get taskId => id;
  @override
  Duration get remaining => left;
  @override
  Duration get sessionLength => length;
  @override
  Duration get sessionFocused => focused ?? length;
  @override
  Duration get focusDuration => const Duration(minutes: 25);
  @override
  double get progress => 0.25;

  @override
  void startForTask(Task t) => started.add(t.id);
  @override
  void startWithoutTask() => startedFree++;
  @override
  void endSession() => ended++;
  @override
  Future<void> completeTask() async => completed++;
  @override
  void pause() => paused++;
  @override
  void start() => resumed++;
  @override
  void keepGoing() => keptGoing++;
  @override
  void dismissFinished() => dismissed++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('bloop_focus_v2_test');
    Hive.init(dir.path);
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(PriorityAdapter());
    Hive.registerAdapter(RecurrenceAdapter());
    await Hive.openBox<Task>(StorageService.tasksBoxName);
    await Hive.openBox<String>(StorageService.tagsBoxName);
    await Hive.openBox(StorageService.settingsBoxName);
  });

  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  // Saturday 17 October 2026, 3:00 PM.
  final now = DateTime(2026, 10, 17, 15);
  final budget = Task(
    id: 'budget',
    title: 'Robotics Club budget sheet',
    dueDateTime: DateTime(2026, 10, 17, 15, 20),
    tags: ['robotics'],
  );
  final essay = Task(
    id: 'essay',
    title: 'Essay outline',
    dueDateTime: DateTime(2026, 10, 17, 21),
  );
  final late = Task(
    id: 'late',
    title: 'Pay fee',
    dueDateTime: DateTime(2026, 10, 15, 9),
  );

  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester,
    _FakeFocus focus, {
    List<Task>? tasks,
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => _FakeSettings()),
        taskListProvider.overrideWith(
          (ref) => _FakeTasks(tasks ?? [budget, essay]),
        ),
        focusControllerProvider.overrideWith((ref) => focus),
        focusClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          home: const Scaffold(body: FocusV2View()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
  }

  group('Ready', () {
    testWidgets('preselects the task that is soon, with its time and tag', (
      tester,
    ) async {
      await pump(tester, _FakeFocus());

      expect(find.text('UP NEXT'), findsOneWidget);
      expect(find.text('Robotics Club budget sheet'), findsOneWidget);
      expect(find.textContaining('3:20'), findsOneWidget);
      expect(find.text('robotics'), findsOneWidget);
      expect(find.text('25:00'), findsOneWidget);
      expect(find.text('25 min · set in Settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Start begins a session for the shown task', (tester) async {
      final focus = _FakeFocus();
      await pump(tester, focus);

      await tester.tap(find.text('Start'));

      expect(focus.started, ['budget']);
      expect(focus.startedFree, 0);
    });

    testWidgets('"Focus without a task" starts with none', (tester) async {
      final focus = _FakeFocus();
      await pump(tester, focus);

      await tester.tap(find.text('Focus without a task'));

      expect(focus.startedFree, 1);
      expect(focus.started, isEmpty);
    });

    testWidgets('the selector lists today\'s open tasks and changes the pick', (
      tester,
    ) async {
      final focus = _FakeFocus();
      await pump(tester, focus, tasks: [budget, essay, late]);

      await tester.tap(find.text('Robotics Club budget sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Choose a task'), findsOneWidget);
      expect(find.text('2 days late'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.text('Essay outline'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a task'), findsNothing);

      await tester.tap(find.text('Start'));
      expect(focus.started, ['essay']);
    });

    testWidgets('a single task is shown without a list to open', (
      tester,
    ) async {
      await pump(tester, _FakeFocus(), tasks: [budget]);

      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
      await tester.tap(find.text('Robotics Club budget sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a task'), findsNothing);
    });

    testWidgets('with only an overdue task, it is offered', (tester) async {
      final focus = _FakeFocus();
      await pump(tester, focus, tasks: [late]);

      expect(find.text('UP NEXT'), findsOneWidget);
      expect(find.text('Pay fee'), findsOneWidget);
      expect(find.text('2 days late'), findsOneWidget);

      await tester.tap(find.text('Start'));
      expect(focus.started, ['late']);
    });

    testWidgets('with nothing due, Start runs a session with no task', (
      tester,
    ) async {
      final focus = _FakeFocus();
      await pump(tester, focus, tasks: []);

      expect(find.text('UP NEXT'), findsNothing);
      expect(find.text('Focus without a task'), findsNothing);
      expect(find.textContaining('Nothing due today'), findsOneWidget);

      await tester.tap(find.text('Start'));
      expect(focus.startedFree, 1);
    });

    testWidgets('the selector reads out its due time and tag', (tester) async {
      await pump(tester, _FakeFocus());

      expect(
        find.bySemanticsLabel(RegExp(r'Task: Robotics.*3:20.*tag robotics')),
        findsOneWidget,
      );
    });

    testWidgets('fits a small phone in both themes', (tester) async {
      for (final dark in [false, true]) {
        tester.view.physicalSize = const Size(720, 1280);
        tester.view.devicePixelRatio = 2;
        await pump(tester, _FakeFocus(), dark: dark);
        tester.view.physicalSize = const Size(720, 1280);
        tester.view.devicePixelRatio = 2;
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('Running', () {
    _FakeFocus running() => _FakeFocus()
      ..active = true
      ..running = true
      ..task = 'Robotics Club budget sheet'
      ..id = 'budget'
      ..left = const Duration(minutes: 18, seconds: 42);

    testWidgets('shows the task, tag, time and three controls', (tester) async {
      await pump(tester, running());

      expect(find.text('FOCUSING ON'), findsOneWidget);
      expect(find.text('Robotics Club budget sheet'), findsOneWidget);
      expect(find.text('robotics'), findsOneWidget);
      expect(find.text('18:42'), findsOneWidget);
      expect(find.text('remaining of 25 min'), findsOneWidget);
      expect(find.bySemanticsLabel('End'), findsOneWidget);
      expect(find.bySemanticsLabel('Pause'), findsOneWidget);
      expect(find.bySemanticsLabel('Done'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Pause pauses; paused it says so and offers Resume', (
      tester,
    ) async {
      final focus = running();
      await pump(tester, focus);

      await tester.tap(find.byIcon(Icons.pause));
      expect(focus.paused, 1);

      focus
        ..running = false
        ..notifyListeners();
      await tester.pump();
      expect(find.text('Paused'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.play_arrow));
      expect(focus.resumed, 1);
    });

    testWidgets('End ends the session and keeps the task', (tester) async {
      final focus = running();
      await pump(tester, focus);

      await tester.tap(find.byIcon(Icons.stop_outlined));

      expect(focus.ended, 1);
      expect(focus.completed, 0);
    });

    testWidgets('Done completes the task and goes back to Tasks', (
      tester,
    ) async {
      final focus = running();
      await pump(tester, focus);
      container.read(selectedTabProvider.notifier).select(focusTabIndex);

      await tester.tap(find.byIcon(Icons.check));

      expect(focus.completed, 1);
      expect(container.read(selectedTabProvider), tasksTabIndex);
    });

    testWidgets('the chevron minimises to Tasks without ending anything', (
      tester,
    ) async {
      final focus = running();
      await pump(tester, focus);
      container.read(selectedTabProvider.notifier).select(focusTabIndex);

      await tester.tap(find.byTooltip('Minimise to Tasks'));

      expect(container.read(selectedTabProvider), tasksTabIndex);
      expect(focus.ended, 0);
    });

    testWidgets('a session with no task has no Done button', (tester) async {
      final focus = running()
        ..task = null
        ..id = null;
      await pump(tester, focus);

      expect(find.text('FOCUS SESSION'), findsOneWidget);
      expect(find.text('Done'), findsNothing);
      expect(find.text('End'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
    });

    testWidgets('fits a short landscape screen', (tester) async {
      tester.view.physicalSize = const Size(1440, 720);
      tester.view.devicePixelRatio = 2;
      await pump(tester, running());
      tester.view.physicalSize = const Size(1440, 720);
      tester.view.devicePixelRatio = 2;
      await tester.pump();

      expect(find.text('18:42'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group("Time's up", () {
    _FakeFocus finished() => _FakeFocus()
      ..finished = true
      ..task = 'Robotics Club budget sheet'
      ..id = 'budget'
      ..left = Duration.zero;

    testWidgets('asks whether the task is finished', (tester) async {
      await pump(tester, finished());

      expect(find.text('25 minutes done'.toUpperCase()), findsOneWidget);
      expect(find.text('Robotics Club budget sheet'), findsOneWidget);
      expect(find.text('Mark task done'), findsOneWidget);
      expect(find.text('Keep going · 5 more min'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports the whole effort after Keep going', (tester) async {
      final focus = finished()
        ..length = const Duration(minutes: 5)
        ..focused = const Duration(minutes: 30);
      await pump(tester, focus);

      expect(find.text('30 MINUTES DONE'), findsOneWidget);
    });

    testWidgets('Mark task done completes it and returns to Tasks', (
      tester,
    ) async {
      final focus = finished();
      await pump(tester, focus);
      container.read(selectedTabProvider.notifier).select(focusTabIndex);

      await tester.tap(find.text('Mark task done'));

      expect(focus.completed, 1);
      expect(container.read(selectedTabProvider), tasksTabIndex);
    });

    testWidgets('Keep going adds time and stays on the screen', (tester) async {
      final focus = finished();
      await pump(tester, focus);
      container.read(selectedTabProvider.notifier).select(focusTabIndex);

      await tester.tap(find.text('Keep going · 5 more min'));

      expect(focus.keptGoing, 1);
      expect(container.read(selectedTabProvider), focusTabIndex);
    });

    testWidgets('Close leaves the task open and returns to Tasks', (
      tester,
    ) async {
      final focus = finished();
      await pump(tester, focus);
      container.read(selectedTabProvider.notifier).select(focusTabIndex);

      await tester.tap(find.text('Close'));

      expect(focus.dismissed, 1);
      expect(focus.completed, 0);
      expect(container.read(selectedTabProvider), tasksTabIndex);
    });

    testWidgets('a session with no task skips Mark task done', (tester) async {
      final focus = finished()
        ..task = null
        ..id = null;
      await pump(tester, focus);

      expect(find.text('Mark task done'), findsNothing);
      expect(find.text('Keep going · 5 more min'), findsOneWidget);
    });
  });
}
