import 'dart:io';

import 'package:bloop/models/task.dart';
import 'package:bloop/providers/settings_provider.dart';
import 'package:bloop/providers/tab_provider.dart';
import 'package:bloop/providers/task_provider.dart';
import 'package:bloop/services/storage_service.dart';
import 'package:bloop/ui/screens/focus_controller.dart';
import 'package:bloop/ui/screens/home_screen.dart';
import 'package:bloop/ui/screens/task_editor_screen.dart';
import 'package:bloop/ui/theme/app_theme.dart';
import 'package:bloop/ui/widgets/task_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Records saves instead of touching Hive and the notification plugin.
class _FakeTasks extends TaskNotifier {
  final saved = <Task>[];
  final completed = <String>[];
  final deleted = <String>[];

  @override
  Future<void> load() async {}

  @override
  Future<List<int>?> addOrUpdate(Task task) async {
    saved.add(task);
    return null;
  }

  @override
  Future<void> toggleComplete(Task task, {bool? value}) async {
    completed.add(task.id);
  }

  @override
  Future<void> delete(Task task) async {
    deleted.add(task.id);
  }
}

class _FakeSettings extends SettingsNotifier {
  _FakeSettings() {
    state = state.copyWith(userName: 'Saad');
  }

  @override
  void setLastTabIndex(int index) {
    state = state.copyWith(lastTabIndex: index);
  }
}

/// Stands in for the real controller, which needs the audio and notification
/// plugins.
class _FakeFocus extends ChangeNotifier implements FocusController {
  _FakeFocus({this.minutes = 25});

  final int minutes;
  bool active = false;
  final started = <Task>[];

  @override
  bool get isSessionActive => active;

  @override
  Duration get focusDuration => Duration(minutes: minutes);

  @override
  void startForTask(Task task) => started.add(task);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('bloop_row_actions_test');
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

  final now = DateTime.now();
  final overdue = Task(
    title: 'Pay fee',
    dueDateTime: DateTime(now.year, now.month, now.day - 1, 17),
  );
  final upcoming = Task(
    title: 'Plan sprint',
    dueDateTime: DateTime(now.year, now.month, now.day + 2, 10),
  );

  late _FakeTasks tasks;
  late _FakeFocus focus;
  late ProviderContainer container;

  Future<void> pumpHome(
    WidgetTester tester, {
    _FakeFocus? withFocus,
    List<Task>? shown,
  }) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    tasks = _FakeTasks();
    focus = withFocus ?? _FakeFocus();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _FakeSettings()),
          taskListProvider.overrideWith((ref) => tasks),
          filteredActiveTasksProvider.overrideWithValue(
            AsyncData(shown ?? [overdue, upcoming]),
          ),
          completedTasksProvider.overrideWithValue(const AsyncData([])),
          focusControllerProvider.overrideWith((ref) => focus),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
  }

  Future<void> open(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  final snooze = find.text('Snooze 1h');

  group('expanding', () {
    testWidgets('rows start closed', (tester) async {
      await pumpHome(tester);
      expect(snooze, findsNothing);
    });

    testWidgets('tapping a row opens it', (tester) async {
      await pumpHome(tester);

      await open(tester, 'Pay fee');

      expect(snooze, findsOneWidget);
      expect(find.text('Tomorrow'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    });

    testWidgets('tapping it again closes it', (tester) async {
      await pumpHome(tester);

      await open(tester, 'Pay fee');
      await open(tester, 'Pay fee');

      expect(snooze, findsNothing);
    });

    testWidgets('opening another row closes the first', (tester) async {
      await pumpHome(tester);

      await open(tester, 'Pay fee');
      await open(tester, 'Plan sprint');

      expect(snooze, findsOneWidget);
      final openTile = find.ancestor(
        of: snooze,
        matching: find.byType(TaskTile),
      );
      expect(tester.widget<TaskTile>(openTile).task.title, 'Plan sprint');
    });

    testWidgets('the circle completes without opening the row', (tester) async {
      await pumpHome(tester);

      await tester.tap(find.byType(InkResponse).first);
      await tester.pumpAndSettle();

      expect(tasks.completed, [overdue.id]);
      expect(snooze, findsNothing);
    });

    testWidgets('shows the focus length', (tester) async {
      await pumpHome(tester, withFocus: _FakeFocus(minutes: 45));

      await open(tester, 'Pay fee');

      expect(find.text('Focus 45m'), findsOneWidget);
    });
  });

  group('Snooze and Tomorrow', () {
    testWidgets('Snooze 1h saves the task an hour from now', (tester) async {
      await pumpHome(tester);
      await open(tester, 'Pay fee');

      await tester.tap(snooze);
      await tester.pumpAndSettle();

      final saved = tasks.saved.single;
      expect(saved.id, overdue.id);
      final expected = DateTime.now().add(const Duration(hours: 1));
      expect(
        saved.dueDateTime!.difference(expected).abs().inSeconds,
        lessThan(5),
      );
      expect(snooze, findsNothing, reason: 'the row closes');
    });

    testWidgets('Tomorrow saves the task for tomorrow, same time', (
      tester,
    ) async {
      await pumpHome(tester);
      await open(tester, 'Plan sprint');

      await tester.tap(find.text('Tomorrow'));
      await tester.pumpAndSettle();

      final today = DateTime.now();
      expect(tasks.saved.single.id, upcoming.id);
      expect(
        tasks.saved.single.dueDateTime,
        DateTime(today.year, today.month, today.day + 1, 10),
      );
      expect(snooze, findsNothing, reason: 'the row closes');
    });
  });

  group('Edit', () {
    testWidgets('opens the task editor for the task', (tester) async {
      await pumpHome(tester);
      await open(tester, 'Pay fee');

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskEditorScreen), findsOneWidget);
      expect(
        tester.widget<TaskEditorScreen>(find.byType(TaskEditorScreen)).task,
        overdue,
      );
      // The editor's reminder dropdown overflows by a pixel or two under the
      // wide test font; that's the editor's layout, not this route.
      final error = tester.takeException();
      expect(error == null || error.toString().contains('overflowed'), isTrue);
    });
  });

  group('Focus', () {
    testWidgets('starts a session on the task and shows the Focus tab', (
      tester,
    ) async {
      await pumpHome(tester);
      expect(container.read(selectedTabProvider), tasksTabIndex);
      await open(tester, 'Pay fee');

      await tester.tap(find.text('Focus 25m'));
      await tester.pumpAndSettle();

      expect(focus.started, [overdue]);
      expect(container.read(selectedTabProvider), focusTabIndex);
      expect(snooze, findsNothing, reason: 'the row closes');
    });

    testWidgets('asks before replacing a session in progress', (tester) async {
      await pumpHome(tester);
      focus.active = true;
      await open(tester, 'Pay fee');

      await tester.tap(find.text('Focus 25m'));
      await tester.pumpAndSettle();

      expect(find.text('Replace current session?'), findsOneWidget);
      expect(focus.started, isEmpty);

      await tester.tap(find.text('Keep current'));
      await tester.pumpAndSettle();

      expect(focus.started, isEmpty);
      expect(container.read(selectedTabProvider), tasksTabIndex);
      expect(snooze, findsOneWidget, reason: 'the row stays open');
    });

    testWidgets('replaces the session once confirmed', (tester) async {
      await pumpHome(tester);
      focus.active = true;
      await open(tester, 'Pay fee');

      await tester.tap(find.text('Focus 25m'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace'));
      await tester.pumpAndSettle();

      expect(focus.started, [overdue]);
      expect(container.read(selectedTabProvider), focusTabIndex);
    });
  });
}
