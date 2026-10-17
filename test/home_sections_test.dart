import 'dart:io';

import 'package:bloop/models/task.dart';
import 'package:bloop/providers/settings_provider.dart';
import 'package:bloop/providers/task_provider.dart';
import 'package:bloop/services/storage_service.dart';
import 'package:bloop/ui/screens/home_screen.dart';
import 'package:bloop/ui/theme/app_theme.dart';
import 'package:bloop/ui/widgets/choice_chip.dart';
import 'package:bloop/ui/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

class _FakeSettings extends SettingsNotifier {
  _FakeSettings() {
    state = state.copyWith(userName: 'Saad');
  }
}

Finder header(String label) => find.widgetWithText(SectionHeader, label);

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('bloop_home_sections_test');
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

  Task task(String title, {DateTime? due, List<String>? tags}) =>
      Task(title: title, dueDateTime: due, tags: tags);

  Future<void> pumpHome(WidgetTester tester, List<Task> tasks) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => _FakeSettings()),
          filteredActiveTasksProvider.overrideWithValue(AsyncData(tasks)),
          completedTasksProvider.overrideWithValue(const AsyncData([])),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  final mixed = [
    task('Pay fee', due: DateTime(now.year, now.month, now.day - 1)),
    task('Lab record', due: DateTime(now.year, now.month, now.day, 23, 59)),
    task('Plan sprint', due: DateTime(now.year, now.month, now.day + 2)),
    task('Laundry'),
    task('Read papers'),
  ];

  testWidgets('groups tasks under headers in order with counts', (
    tester,
  ) async {
    await pumpHome(tester, mixed);

    final labels = [
      for (final w in tester.widgetList<SectionHeader>(
        find.byType(SectionHeader),
      ))
        w.label,
    ];
    expect(labels, ['Overdue', 'Today', 'Upcoming', 'Whenever']);
    expect(tester.widget<SectionHeader>(header('Whenever')).count, 2);
    expect(tester.widget<SectionHeader>(header('Overdue')).count, 1);
  });

  testWidgets('Today header carries the date', (tester) async {
    await pumpHome(tester, mixed);

    expect(
      tester.widget<SectionHeader>(header('Today')).date,
      DateFormat.MMMEd().format(now),
    );
    expect(tester.widget<SectionHeader>(header('Overdue')).date, isNull);
  });

  testWidgets('hides empty sections', (tester) async {
    await pumpHome(tester, [
      task('Lab record', due: DateTime(now.year, now.month, now.day, 23, 59)),
    ]);

    expect(header('Today'), findsOneWidget);
    expect(header('Overdue'), findsNothing);
    expect(header('Upcoming'), findsNothing);
    expect(header('Whenever'), findsNothing);
  });

  testWidgets('Whenever starts collapsed, the others open', (tester) async {
    await pumpHome(tester, mixed);

    expect(find.text('Pay fee'), findsOneWidget);
    expect(find.text('Lab record'), findsOneWidget);
    expect(find.text('Plan sprint'), findsOneWidget);
    expect(find.text('Laundry'), findsNothing);
    expect(find.text('Read papers'), findsNothing);
    expect(tester.widget<SectionHeader>(header('Whenever')).expanded, isFalse);
  });

  testWidgets('tapping a header toggles its tasks', (tester) async {
    await pumpHome(tester, mixed);

    await tester.tap(header('Whenever'));
    await tester.pumpAndSettle();
    expect(find.text('Laundry'), findsOneWidget);

    await tester.tap(header('Whenever'));
    await tester.pumpAndSettle();
    expect(find.text('Laundry'), findsNothing);

    await tester.tap(header('Overdue'));
    await tester.pumpAndSettle();
    expect(find.text('Pay fee'), findsNothing);
    expect(find.text('Lab record'), findsOneWidget);
  });

  testWidgets('a collapsed section still shows its count', (tester) async {
    await pumpHome(tester, mixed);

    expect(
      find.descendant(of: header('Whenever'), matching: find.text('2')),
      findsOneWidget,
    );
  });

  testWidgets('empty copy', (tester) async {
    await pumpHome(tester, const []);

    expect(
      find.text('No tasks yet\nTap + to add your first one.'),
      findsOneWidget,
    );
    expect(find.byType(SectionHeader), findsNothing);
    expect(find.byType(BloopChoiceChip), findsOneWidget);
  });
}
