import 'dart:typed_data';

import 'package:bloop/models/task.dart';
import 'package:bloop/providers/settings_provider.dart';
import 'package:bloop/providers/task_provider.dart';
import 'package:bloop/services/notif_service.dart';
import 'package:bloop/services/storage_service.dart';
import 'package:bloop/ui/screens/focus_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _Settings extends SettingsNotifier {
  _Settings({required bool v2}) {
    state = state.copyWith(focusV2Enabled: v2);
  }

  @override
  void setFocusV2Enabled(bool value) {
    state = state.copyWith(focusV2Enabled: value);
  }
}

class _Tasks extends TaskNotifier {
  _Tasks(List<Task> tasks) {
    state = AsyncData(tasks);
  }

  final completed = <String>[];

  @override
  Future<void> load() async {}

  @override
  Future<void> toggleComplete(Task task, {bool? value}) async {
    completed.add(task.id);
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(PriorityAdapter());
    Hive.registerAdapter(RecurrenceAdapter());
    await Hive.openBox<Task>(StorageService.tasksBoxName, bytes: Uint8List(0));
    await Hive.openBox<String>(StorageService.tagsBoxName, bytes: Uint8List(0));
    await Hive.openBox(StorageService.settingsBoxName, bytes: Uint8List(0));
  });

  tearDownAll(() async {
    await Hive.close();
  });

  final budget = Task(id: 'budget', title: 'Robotics Club budget sheet');

  late _Tasks tasks;
  late _Settings settings;
  late ProviderContainer container;

  FocusController make({bool v2 = true}) {
    tasks = _Tasks([budget]);
    settings = _Settings(v2: v2);
    container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => settings),
        taskListProvider.overrideWith((ref) => tasks),
        focusControllerProvider.overrideWith(
          (ref) => FocusController(ref: ref, notifService: _QuietNotifs()),
        ),
      ],
    );
    addTearDown(container.dispose);
    final c = container.read(focusControllerProvider);
    // The audio plugin isn't available under test.
    c.updateSessionPreferences(soundsEnabled: false);
    return c;
  }

  group('with the new screen on', () {
    test('a session for a task keeps its id and the planned length', () {
      final c = make();

      c.startForTask(budget);

      expect(c.isSessionActive, isTrue);
      expect(c.isRunning, isTrue);
      expect(c.taskId, 'budget');
      expect(c.taskTitle, 'Robotics Club budget sheet');
      expect(c.sessionLength, const Duration(minutes: 25));
      expect(c.isFinished, isFalse);
    });

    test('running out ends in Time\'s up, not a break', () {
      final c = make()..startForTask(budget);

      c.finishNowForTest();

      expect(c.isFinished, isTrue);
      expect(c.isSessionActive, isFalse);
      expect(c.isRunning, isFalse);
      expect(c.remaining, Duration.zero);
      expect(c.isFocusSession, isTrue);
      expect(c.taskId, 'budget');
      expect(c.progress, 1);
    });

    test('Keep going adds five minutes to the same task', () {
      final c = make()
        ..startForTask(budget)
        ..finishNowForTest();

      c.keepGoing();

      expect(c.isFinished, isFalse);
      expect(c.isRunning, isTrue);
      expect(c.taskId, 'budget');
      expect(c.sessionLength, const Duration(minutes: 5));
      expect(c.remaining, const Duration(minutes: 5));
      expect(c.progress, closeTo(0, 0.01));
    });

    test('Time\'s up after Keep going reports the whole effort', () {
      final c = make()
        ..startForTask(budget)
        ..finishNowForTest()
        ..keepGoing();
      expect(c.sessionFocused, const Duration(minutes: 30));

      c.finishNowForTest();

      expect(c.isFinished, isTrue);
      expect(c.sessionLength, const Duration(minutes: 5));
      expect(c.sessionFocused, const Duration(minutes: 30));

      c.dismissFinished();
      expect(c.sessionFocused, const Duration(minutes: 25));
    });

    test('Close clears the task and goes back to ready', () {
      final c = make()
        ..startForTask(budget)
        ..finishNowForTest();

      c.dismissFinished();

      expect(c.isFinished, isFalse);
      expect(c.isSessionActive, isFalse);
      expect(c.taskId, isNull);
      expect(c.taskTitle, isNull);
      expect(tasks.completed, isEmpty);
    });

    test('End stops the session and leaves the task open', () {
      final c = make()..startForTask(budget);

      c.endSession();

      expect(c.isSessionActive, isFalse);
      expect(c.isRunning, isFalse);
      expect(c.taskId, isNull);
      expect(tasks.completed, isEmpty);
    });

    test('Done ends the session and completes the task', () async {
      final c = make()..startForTask(budget);

      await c.completeTask();

      expect(c.isSessionActive, isFalse);
      expect(c.taskId, isNull);
      expect(tasks.completed, ['budget']);
    });

    test('completing from Time\'s up completes the task too', () async {
      final c = make()
        ..startForTask(budget)
        ..finishNowForTest();

      await c.completeTask();

      expect(c.isFinished, isFalse);
      expect(tasks.completed, ['budget']);
    });

    test('a session with no task completes nothing', () async {
      final c = make()..startWithoutTask();

      expect(c.isRunning, isTrue);
      expect(c.taskId, isNull);

      await c.completeTask();

      expect(c.isSessionActive, isFalse);
      expect(tasks.completed, isEmpty);
    });

    test('pausing and resuming keeps the ring measured against the start', () {
      final c = make()..startForTask(budget);

      c.pause();
      expect(c.isRunning, isFalse);
      expect(c.sessionLength, const Duration(minutes: 25));

      c.start();
      expect(c.isRunning, isTrue);
      expect(c.sessionLength, const Duration(minutes: 25));
    });

    test('a task started while Time\'s up shows replaces it', () {
      final c = make()
        ..startForTask(budget)
        ..finishNowForTest();

      c.startForTask(Task(id: 'other', title: 'Other'));

      expect(c.isFinished, isFalse);
      expect(c.taskId, 'other');
    });
  });

  group('with the new screen off', () {
    test('running out still moves on to a break', () {
      final c = make(v2: false)..startForTask(budget);

      c.finishNowForTest();

      expect(c.isFinished, isFalse);
      expect(c.isFocusSession, isFalse);
      expect(c.sessionLabel, 'Short break');
    });
  });

  test('switching the new screen off leaves Time\'s up', () {
    final c = make()
      ..startForTask(budget)
      ..finishNowForTest();
    expect(c.isFinished, isTrue);

    settings.setFocusV2Enabled(false);

    expect(c.isFinished, isFalse);
    expect(c.isSessionActive, isFalse);
    expect(c.taskId, isNull);
  });

  test('switching the new screen on leaves a break that was in progress', () {
    final c = make(v2: false)
      ..startForTask(budget)
      ..finishNowForTest();
    expect(c.isFocusSession, isFalse);

    settings.setFocusV2Enabled(true);

    expect(c.isFocusSession, isTrue);
    expect(c.isSessionActive, isFalse);
  });
}
