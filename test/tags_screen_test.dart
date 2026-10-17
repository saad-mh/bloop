import 'dart:typed_data';

import 'package:bloop/models/task.dart';
import 'package:bloop/providers/tags_provider.dart';
import 'package:bloop/providers/task_provider.dart';
import 'package:bloop/services/storage_service.dart';
import 'package:bloop/ui/screens/tags_screen.dart';
import 'package:bloop/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Runs the screen against real storage, so rename and delete are checked
/// through to the tasks. The boxes live in memory: file I/O never completes
/// under the fake clock widget tests run on.
void main() {
  final storage = StorageService.instance;

  setUpAll(() async {
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(PriorityAdapter());
    Hive.registerAdapter(RecurrenceAdapter());
    await Hive.openBox<Task>(
      StorageService.tasksBoxName,
      bytes: Uint8List(0),
    );
    await Hive.openBox<String>(
      StorageService.tagsBoxName,
      bytes: Uint8List(0),
    );
  });

  tearDownAll(() async {
    await Hive.close();
  });

  late ProviderContainer container;

  Future<Task> put(String title, List<String> tags, {bool done = false}) async {
    final task = Task(title: title, tags: tags, isCompleted: done);
    await storage.upsert(task);
    return storage.getById(task.id)!;
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light, home: const TagsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() async {
    await Hive.box<Task>(StorageService.tasksBoxName).clear();
    await Hive.box<String>(StorageService.tagsBoxName).clear();
    await storage.addTag('college');
    await storage.addTag('robotics');
  });

  testWidgets('lists each tag with its open task count', (tester) async {
    await put('a', ['college']);
    await put('b', ['college']);
    await put('c', ['college'], done: true);
    await open(tester);

    expect(find.textContaining('college'), findsOneWidget);
    expect(find.textContaining('2 open'), findsOneWidget);
    expect(find.textContaining('0 open'), findsOneWidget);
  });

  testWidgets('adds a tag and rejects empty and duplicate names', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name for the tag'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'COLLEGE');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('A tag with that name already exists'), findsOneWidget);
    expect(storage.getTags(), ['college', 'robotics']);

    await tester.enterText(find.byType(TextField), '  research ');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(storage.getTags(), ['college', 'research', 'robotics']);
    expect(find.textContaining('research'), findsOneWidget);
    expect(find.text('A tag with that name already exists'), findsNothing);
  });

  testWidgets('renaming updates the tasks and keeps the home filter', (
    tester,
  ) async {
    final task = await put('a', ['college']);
    await open(tester);
    container.read(selectedTagProvider.notifier).state = 'college';

    await tester.tap(find.byTooltip('Edit college tag'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'college'), 'uni');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(storage.getTags(), ['robotics', 'uni']);
    expect(storage.getById(task.id)!.tags, ['uni']);
    expect(container.read(tagOpenCountsProvider), {'uni': 1});
    expect(container.read(effectiveTagProvider), 'uni');
  });

  testWidgets('renaming to another tag\'s name shows an error', (tester) async {
    await open(tester);

    await tester.tap(find.byTooltip('Edit college tag'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'college'),
      'Robotics',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('A tag with that name already exists'), findsOneWidget);
    expect(find.text('Edit tag'), findsOneWidget);
    expect(storage.getTags(), ['college', 'robotics']);
  });

  testWidgets('delete shows the impact, then strips the tag from tasks', (
    tester,
  ) async {
    final open1 = await put('a', ['college', 'robotics']);
    final done = await put('b', ['college'], done: true);
    await open(tester);

    await tester.tap(find.byTooltip('Edit college tag'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.textContaining('removed from 2 tasks (1 open, 1 completed)'),
        findsOneWidget);
    // Nothing is deleted until confirmed.
    expect(storage.getTags(), contains('college'));

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(storage.getTags(), ['robotics']);
    expect(storage.getById(open1.id)!.tags, ['robotics']);
    expect(storage.getById(done.id)!.tags, isEmpty);
    expect(find.textContaining('college'), findsNothing);
  });

  testWidgets('cancelling the delete confirmation keeps the tag', (
    tester,
  ) async {
    final task = await put('a', ['college']);
    await open(tester);

    await tester.tap(find.byTooltip('Edit college tag'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(storage.getTags(), contains('college'));
    expect(storage.getById(task.id)!.tags, ['college']);
  });
}
