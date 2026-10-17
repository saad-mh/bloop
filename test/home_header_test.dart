import 'dart:io';

import 'package:bloop/models/task.dart';
import 'package:bloop/providers/settings_provider.dart';
import 'package:bloop/providers/tags_provider.dart';
import 'package:bloop/providers/task_provider.dart';
import 'package:bloop/services/storage_service.dart';
import 'package:bloop/ui/screens/home_screen.dart';
import 'package:bloop/ui/theme/app_theme.dart';
import 'package:bloop/ui/widgets/choice_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Settings with a fixed name, whatever is stored in Hive.
class _FakeSettings extends SettingsNotifier {
  _FakeSettings(String name) {
    state = state.copyWith(userName: name);
  }
}

/// Header chip for [label]; task rows also show tags as plain text.
Finder chip(String label) => find.widgetWithText(BloopChoiceChip, label);

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('bloop_home_header_test');
    Hive.init(dir.path);
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(PriorityAdapter());
    Hive.registerAdapter(RecurrenceAdapter());
    final tasks = await Hive.openBox<Task>(StorageService.tasksBoxName);
    final tags = await Hive.openBox<String>(StorageService.tagsBoxName);
    await Hive.openBox(StorageService.settingsBoxName);

    for (final tag in ['college', 'robotics']) {
      await tags.put(tag, tag);
    }
    for (final task in [
      Task(id: 'a', title: 'Lab record', tags: ['college']),
      Task(id: 'b', title: 'Budget sheet', tags: ['robotics']),
      Task(id: 'c', title: 'Buy milk'),
      Task(
        id: 'd',
        title: 'Old essay',
        tags: ['college'],
        isCompleted: true,
        completedAt: DateTime.now(),
      ),
    ]) {
      await tasks.put(task.id, task);
    }
  });

  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Future<void> pumpHome(WidgetTester tester, {String name = 'Saad'}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _FakeSettings(name)),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('greets by first name', (tester) async {
    await pumpHome(tester, name: 'Saad Ansari');

    expect(find.textContaining(RegExp(r'^Good \w+, Saad$')), findsOneWidget);
  });

  testWidgets('greets without a comma when no name is set', (tester) async {
    await pumpHome(tester, name: '');

    expect(find.textContaining(RegExp(r'^Good \w+$')), findsOneWidget);
  });

  testWidgets('old title and filter menu are gone', (tester) async {
    await pumpHome(tester);

    expect(find.text('Today'), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.byTooltip('Settings'), findsOneWidget);
    expect(find.byTooltip('Search'), findsOneWidget);
  });

  testWidgets('shows All plus a chip per tag, All selected', (tester) async {
    await pumpHome(tester);

    expect(chip('All'), findsOneWidget);
    expect(chip('college'), findsOneWidget);
    expect(chip('robotics'), findsOneWidget);
    expect(find.text('Lab record'), findsOneWidget);
    expect(find.text('Budget sheet'), findsOneWidget);
    expect(find.text('Buy milk'), findsOneWidget);
    // Completed tasks stay out of the home list.
    expect(find.text('Old essay'), findsNothing);
  });

  testWidgets('a tag chip filters the list and All clears it', (tester) async {
    await pumpHome(tester);

    await tester.tap(chip('college'));
    await tester.pumpAndSettle();
    expect(find.text('Lab record'), findsOneWidget);
    expect(find.text('Budget sheet'), findsNothing);
    expect(find.text('Buy milk'), findsNothing);

    await tester.tap(chip('All'));
    await tester.pumpAndSettle();
    expect(find.text('Budget sheet'), findsOneWidget);
    expect(find.text('Buy milk'), findsOneWidget);
  });

  testWidgets('tapping the selected tag chip again clears the filter', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(chip('robotics'));
    await tester.pumpAndSettle();
    expect(find.text('Lab record'), findsNothing);

    await tester.tap(chip('robotics'));
    await tester.pumpAndSettle();
    expect(find.text('Lab record'), findsOneWidget);
  });

  testWidgets('search ignores the tag chip and includes completed tasks', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(chip('robotics'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    // Active task outside the selected tag.
    await tester.enterText(find.byType(TextField), 'milk');
    await tester.pumpAndSettle();
    expect(find.text('Buy milk'), findsOneWidget);

    // Completed task.
    await tester.enterText(find.byType(TextField), 'essay');
    await tester.pumpAndSettle();
    expect(find.text('Old essay'), findsOneWidget);
  });

  testWidgets('deleting the selected tag clears the stored choice', (
    tester,
  ) async {
    await pumpHome(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );

    await tester.runAsync(
      () => container.read(tagsProvider.notifier).addTag('temp'),
    );
    await tester.pumpAndSettle();
    // The wide test font pushes the new chip off the right edge.
    await tester.scrollUntilVisible(
      chip('temp'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(chip('temp'));
    await tester.pumpAndSettle();
    expect(container.read(selectedTagProvider), 'temp');

    await tester.runAsync(
      () => container.read(tagsProvider.notifier).deleteTag('temp'),
    );
    await tester.pumpAndSettle();

    expect(container.read(selectedTagProvider), isNull);
    expect(chip('All'), findsOneWidget);
    expect(find.text('Buy milk'), findsOneWidget);
  });
}
