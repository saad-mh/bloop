import 'dart:io';

import 'package:bloop/main.dart';
import 'package:bloop/models/task.dart';
import 'package:bloop/providers/settings_provider.dart';
import 'package:bloop/services/storage_service.dart';
import 'package:bloop/ui/screens/settings_screen.dart';
import 'package:bloop/ui/screens/task_editor_screen.dart';
import 'package:bloop/ui/widgets/floating_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Settings that start on [tab] and record saves instead of writing to Hive,
/// whose unawaited writes can't complete under the test's fake async.
class _FakeSettings extends SettingsNotifier {
  _FakeSettings(int tab) {
    state = state.copyWith(lastTabIndex: tab);
  }

  final saved = <int>[];

  @override
  void setLastTabIndex(int index) {
    saved.add(index);
    state = state.copyWith(lastTabIndex: index);
  }
}

void main() {
  late Directory dir;

  setUpAll(() async {
    // StorageService.init() calls Hive.initFlutter, which needs a platform
    // path, so set up the same adapters and boxes against a temp directory.
    dir = await Directory.systemTemp.createTemp('bloop_test');
    Hive.init(dir.path);
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(PriorityAdapter());
    Hive.registerAdapter(RecurrenceAdapter());
    await Hive.openBox<Task>(StorageService.tasksBoxName);
    await Hive.openBox<String>(StorageService.tagsBoxName);
    await Hive.openBox(StorageService.settingsBoxName);
  });

  Future<_FakeSettings> pumpShell(WidgetTester tester, {int tab = 0}) async {
    // Phone-sized surface, as the app is designed for.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final settings = _FakeSettings(tab);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => settings)],
        child: const BloopApp(),
      ),
    );
    await tester.pumpAndSettle();
    return settings;
  }

  // The header can also read "Tasks" when the greeting doesn't fit.
  final navTasks = find.descendant(
    of: find.byType(FloatingNav),
    matching: find.text('Tasks'),
  );

  int shownTab(WidgetTester tester) =>
      tester.widget<IndexedStack>(find.byType(IndexedStack).first).index!;

  testWidgets('Smoke test builds app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BloopApp()));
    await tester.pumpAndSettle();

    expect(find.text('Tasks'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nav has Tasks, Focus and New task only', (tester) async {
    await pumpShell(tester);

    expect(find.byType(FloatingNav), findsOneWidget);
    expect(find.text('Focus'), findsOneWidget);
    expect(find.byTooltip('New task'), findsOneWidget);
    expect(find.text('Completed'), findsNothing);
    expect(find.text('Preferences'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('New task opens the task editor', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.byTooltip('New task'));
    await tester.pumpAndSettle();

    expect(find.byType(TaskEditorScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('header gear opens Settings', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('selecting a tab shows it and saves its index', (tester) async {
    final settings = await pumpShell(tester);

    await tester.tap(find.text('Focus'));
    await tester.pumpAndSettle();
    expect(shownTab(tester), 1);

    await tester.tap(navTasks);
    await tester.pumpAndSettle();
    expect(shownTab(tester), 0);

    expect(settings.saved, [1, 0]);
  });

  testWidgets('re-selecting the current tab does not save', (tester) async {
    final settings = await pumpShell(tester);

    await tester.tap(navTasks);
    await tester.pumpAndSettle();

    expect(settings.saved, isEmpty);
  });

  testWidgets('starts on the saved tab', (tester) async {
    await pumpShell(tester, tab: 1);

    expect(shownTab(tester), 1);
  });

  testWidgets('a stored index from the old four-tab bar falls back to Tasks', (
    tester,
  ) async {
    // Older builds had four tabs; 3 was Preferences.
    await pumpShell(tester, tab: 3);

    expect(shownTab(tester), 0);
    expect(tester.takeException(), isNull);
  });
}
