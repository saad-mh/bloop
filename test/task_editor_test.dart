import 'dart:io';

import 'package:bloop/models/recurrence.dart';
import 'package:bloop/models/task.dart';
import 'package:bloop/providers/settings_provider.dart';
import 'package:bloop/providers/tags_provider.dart';
import 'package:bloop/providers/task_provider.dart';
import 'package:bloop/services/storage_service.dart';
import 'package:bloop/ui/screens/task_editor_screen.dart';
import 'package:bloop/ui/theme/app_theme.dart';
import 'package:bloop/ui/widgets/choice_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records saves instead of touching Hive and the notification plugin.
class _FakeTasks extends TaskNotifier {
  final saved = <Task>[];
  final deleted = <String>[];

  @override
  Future<void> load() async {}

  @override
  Future<List<int>?> addOrUpdate(Task task) async {
    saved.add(task);
    return <int>[];
  }

  @override
  Future<void> delete(Task task) async {
    deleted.add(task.id);
  }
}

class _FakeTags extends TagsNotifier {
  _FakeTags(List<String> names) : super(StorageService.instance) {
    state = AsyncData(names);
  }

  final added = <String>[];

  @override
  Future<void> addTag(String tag) async {
    added.add(tag);
    state = AsyncData([...state.value!, tag]);
  }
}

void main() {
  late Directory dir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('bloop_editor_test');
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

  late _FakeTasks tasks;
  late _FakeTags tags;

  /// Opens the editor over a home page, so closing it is observable.
  Future<void> openEditor(WidgetTester tester, {Task? task}) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    tasks = _FakeTasks();
    tags = _FakeTags(['college', 'robotics']);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => SettingsNotifier()),
          taskListProvider.overrideWith((ref) => tasks),
          tagsProvider.overrideWith((ref) => tags),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TaskEditorScreen(task: task),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  final editor = find.byType(TaskEditorScreen);

  Future<void> typeTitle(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.pump();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  BloopChoiceChip chip(WidgetTester tester, String label) => tester
      .widget<BloopChoiceChip>(find.widgetWithText(BloopChoiceChip, label));

  final tomorrow = DateTime.now().add(const Duration(days: 2));
  Task dueSoon({List<Duration> reminders = const []}) => Task(
    title: 'Plan sprint',
    dueDateTime: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10),
    reminderMinutesList: [for (final r in reminders) r.inMinutes],
  );

  group('new task', () {
    testWidgets('has a close button, a heading and a focused title', (
      tester,
    ) async {
      await openEditor(tester);

      expect(find.text('New task'), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(find.text('Add task'), findsOneWidget);
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.focusNode.hasFocus, isTrue);
    });

    testWidgets('needs a title to save', (tester) async {
      await openEditor(tester);

      await tap(tester, find.text('Add task'));

      expect(find.text('Add a title to save this task'), findsOneWidget);
      expect(tasks.saved, isEmpty);
      expect(editor, findsOneWidget);
    });

    testWidgets('saves with nothing else chosen and closes', (tester) async {
      await openEditor(tester);
      await typeTitle(tester, '  Buy milk ');

      await tap(tester, find.text('Add task'));

      final task = tasks.saved.single;
      expect(task.title, 'Buy milk');
      expect(task.dueDateTime, isNull);
      expect(task.priority, Priority.medium);
      expect(task.tags, isEmpty);
      expect(editor, findsNothing);
    });

    testWidgets('Today saves an all-day task for today', (tester) async {
      await openEditor(tester);
      await typeTitle(tester, 'Call home');

      await tap(tester, find.text('Today'));
      await tap(tester, find.text('Add task'));

      final task = tasks.saved.single;
      final now = DateTime.now();
      expect(task.dueDateTime, DateTime(now.year, now.month, now.day));
      expect(task.allDay, isTrue);
      expect(editor, findsNothing);
    });

    testWidgets('tapping the chosen day again clears it', (tester) async {
      await openEditor(tester);
      await typeTitle(tester, 'Call home');

      await tap(tester, find.text('Tomorrow'));
      await tap(tester, find.text('Tomorrow'));
      await tap(tester, find.text('Add task'));

      expect(tasks.saved.single.dueDateTime, isNull);
    });

    testWidgets('Remind me is disabled until a time is set', (tester) async {
      await openEditor(tester);

      expect(chip(tester, 'Remind me').onSelected, isNull);

      await tap(tester, find.text('Tomorrow'));
      expect(chip(tester, 'Remind me').onSelected, isNull);

      await tap(tester, find.text('Add time'));
      await tap(tester, find.text('OK'));
      expect(chip(tester, 'Remind me').onSelected, isNotNull);
    });

    testWidgets('a first time brings in the default reminder', (tester) async {
      await openEditor(tester);
      await typeTitle(tester, 'Stand-up');

      await tap(tester, find.text('Tomorrow'));
      await tap(tester, find.text('Add time'));
      await tap(tester, find.text('OK'));

      expect(chip(tester, 'Remind me').selected, isTrue);

      await tap(tester, find.text('Add task'));
      final task = tasks.saved.single;
      expect(task.allDay, isFalse);
      expect(task.remindersBefore, [const Duration(minutes: 30)]);
    });

    testWidgets('Remind me can be turned off again', (tester) async {
      await openEditor(tester);
      await typeTitle(tester, 'Stand-up');

      await tap(tester, find.text('Tomorrow'));
      await tap(tester, find.text('Add time'));
      await tap(tester, find.text('OK'));
      await tap(tester, find.text('Remind me'));

      expect(chip(tester, 'Remind me').selected, isFalse);
      await tap(tester, find.text('Add task'));
      expect(tasks.saved.single.remindersBefore, isEmpty);
    });

    testWidgets('priority defaults to Normal and can be changed', (
      tester,
    ) async {
      await openEditor(tester);
      await typeTitle(tester, 'Ship it');

      await tap(tester, find.text('High'));
      await tap(tester, find.text('Add task'));

      expect(tasks.saved.single.priority, Priority.high);
    });

    testWidgets('tags are picked from the existing ones, several at once', (
      tester,
    ) async {
      await openEditor(tester);
      await typeTitle(tester, 'Lab report');

      await tap(tester, find.text('college'));
      await tap(tester, find.text('robotics'));

      // Selection shows a tick, not just a colour.
      expect(chip(tester, 'college').selected, isTrue);
      expect(
        find.descendant(
          of: find.widgetWithText(BloopChoiceChip, 'college'),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );

      await tap(tester, find.text('Add task'));
      expect(tasks.saved.single.tags, ['college', 'robotics']);
    });

    testWidgets('a new tag is stored and selected', (tester) async {
      await openEditor(tester);
      await typeTitle(tester, 'Lab report');

      await tap(tester, find.text('New tag'));
      await tester.enterText(find.byType(TextField).last, 'errands');
      await tap(tester, find.text('Add'));

      expect(tags.added, ['errands']);
      expect(chip(tester, 'errands').selected, isTrue);
    });
  });

  group('more options', () {
    testWidgets('start closed, with no delete on a new task', (tester) async {
      await openEditor(tester);

      expect(find.text('Notes'), findsNothing);

      await tap(tester, find.text('More options'));

      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Repeat'), findsOneWidget);
      expect(find.text('All day'), findsOneWidget);
      expect(find.text('Pick a date to add reminders.'), findsOneWidget);
      expect(find.text('Delete task'), findsNothing);
    });

    testWidgets('notes and repeat are saved', (tester) async {
      await openEditor(tester);
      await typeTitle(tester, 'Water plants');

      await tap(tester, find.text('More options'));
      await tester.enterText(find.widgetWithText(TextField, 'Notes'), 'Fern');
      await tap(tester, find.text('Never'));
      await tap(tester, find.text('Weekly').last);
      await tap(tester, find.text('Add task'));

      final task = tasks.saved.single;
      expect(task.notes, 'Fern');
      expect(task.recurrence, Recurrence.weekly);
    });

    testWidgets('a second reminder can be added', (tester) async {
      await openEditor(
        tester,
        task: dueSoon(reminders: [const Duration(minutes: 30)]),
      );

      await tap(tester, find.text('More options'));
      expect(find.text('Reminder 2'), findsOneWidget);
    });
  });

  group('edit task', () {
    testWidgets('is prefilled and says Save', (tester) async {
      await openEditor(tester, task: dueSoon());

      expect(find.text('Edit task'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Plan sprint'), findsOneWidget);
    });

    testWidgets('opens More options when the task already uses them', (
      tester,
    ) async {
      await openEditor(tester, task: dueSoon()..notes = 'Bring slides');

      expect(find.text('Bring slides'), findsOneWidget);
    });

    testWidgets('Remind me adds the default reminder', (tester) async {
      await openEditor(tester, task: dueSoon());

      expect(chip(tester, 'Remind me').selected, isFalse);
      await tap(tester, find.text('Remind me'));
      await tap(tester, find.text('Save'));

      expect(tasks.saved.single.remindersBefore, [const Duration(minutes: 30)]);
    });

    testWidgets('removing the only reminder really removes it', (tester) async {
      await openEditor(
        tester,
        task: dueSoon(reminders: [const Duration(minutes: 30)]),
      );

      await tap(tester, find.text('Remind me'));
      await tap(tester, find.text('Save'));

      expect(tasks.saved.single.remindersBefore, isEmpty);
    });

    testWidgets('Clear removes the date and its reminders', (tester) async {
      await openEditor(
        tester,
        task: dueSoon(reminders: [const Duration(minutes: 30)]),
      );

      await tap(tester, find.text('Clear'));
      await tap(tester, find.text('Save'));

      final task = tasks.saved.single;
      expect(task.dueDateTime, isNull);
      expect(task.remindersBefore, isEmpty);
    });

    testWidgets('an overdue task can still be renamed', (tester) async {
      final late = Task(
        title: 'Pay fee',
        dueDateTime: DateTime.now().subtract(const Duration(days: 3)),
      );
      await openEditor(tester, task: late);

      await typeTitle(tester, 'Pay the fee');
      await tap(tester, find.text('Save'));

      expect(tasks.saved.single.title, 'Pay the fee');
      expect(find.textContaining('already passed'), findsNothing);
    });

    testWidgets('a time that has passed is refused when it is new', (
      tester,
    ) async {
      await openEditor(tester);
      await typeTitle(tester, 'Too late');

      await tap(tester, find.text('Pick date'));
      // The picker opens on today; pick a day in the past via its input mode.
      await tap(tester, find.byIcon(Icons.edit_outlined));
      final field = find.byType(TextField).last;
      final past = DateTime.now().subtract(const Duration(days: 2));
      await tester.enterText(
        field,
        '${past.month.toString().padLeft(2, '0')}/'
        '${past.day.toString().padLeft(2, '0')}/${past.year}',
      );
      await tap(tester, find.text('OK'));
      await tap(tester, find.text('Add time'));
      await tap(tester, find.text('OK'));
      await tap(tester, find.text('Add task'));

      expect(find.textContaining('already passed'), findsOneWidget);
      expect(tasks.saved, isEmpty);
    });

    testWidgets('Delete asks first, then removes the task', (tester) async {
      final task = dueSoon();
      await openEditor(tester, task: task);

      await tap(tester, find.text('More options'));
      await tap(tester, find.text('Delete task'));
      expect(tasks.deleted, isEmpty);

      await tap(tester, find.text('Delete').last);

      expect(tasks.deleted, [task.id]);
      expect(editor, findsNothing);
    });

    testWidgets('Delete can be cancelled', (tester) async {
      await openEditor(tester, task: dueSoon());

      await tap(tester, find.text('More options'));
      await tap(tester, find.text('Delete task'));
      await tap(tester, find.text('Cancel'));

      expect(tasks.deleted, isEmpty);
      expect(editor, findsOneWidget);
    });
  });

  group('closing', () {
    testWidgets('closes straight away when nothing was entered', (
      tester,
    ) async {
      await openEditor(tester);

      await tap(tester, find.byTooltip('Close'));

      expect(editor, findsNothing);
    });

    testWidgets('asks before discarding entered text', (tester) async {
      await openEditor(tester);
      await typeTitle(tester, 'Half a thought');

      await tap(tester, find.byTooltip('Close'));

      expect(find.text('Discard this task?'), findsOneWidget);
      expect(editor, findsOneWidget);
    });

    testWidgets('Keep editing stays on the page with the text', (tester) async {
      await openEditor(tester);
      await typeTitle(tester, 'Half a thought');

      await tap(tester, find.byTooltip('Close'));
      await tap(tester, find.text('Keep editing'));

      expect(editor, findsOneWidget);
      expect(find.text('Half a thought'), findsOneWidget);
      expect(find.text('Discard this task?'), findsNothing);
    });

    testWidgets('Discard closes without saving', (tester) async {
      await openEditor(tester);
      await typeTitle(tester, 'Half a thought');

      await tap(tester, find.byTooltip('Close'));
      await tap(tester, find.text('Discard'));

      expect(editor, findsNothing);
      expect(tasks.saved, isEmpty);
    });

    testWidgets('the system back gesture asks too', (tester) async {
      await openEditor(tester);
      await typeTitle(tester, 'Half a thought');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Discard this task?'), findsOneWidget);
    });

    testWidgets('editing without changes closes straight away', (tester) async {
      await openEditor(tester, task: dueSoon());

      await tap(tester, find.byTooltip('Close'));

      expect(editor, findsNothing);
    });

    testWidgets('a changed priority counts as a change', (tester) async {
      await openEditor(tester, task: dueSoon());

      await tap(tester, find.text('High'));
      await tap(tester, find.byTooltip('Close'));

      expect(find.text('Discard changes?'), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('the button rides above the keyboard', (tester) async {
      await openEditor(tester);
      final before = tester.getBottomLeft(find.text('Add task')).dy;

      tester.view.viewInsets = const FakeViewPadding(bottom: 900);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      final after = tester.getBottomLeft(find.text('Add task')).dy;
      expect(after, lessThan(before));
      expect(
        after,
        lessThanOrEqualTo(tester.view.physicalSize.height / 3 - 900 / 3),
      );
    });
  });
}
