import 'dart:convert';

import 'package:bloop/models/task.dart';
import 'package:bloop/providers/settings_provider.dart';
import 'package:bloop/providers/task_provider.dart';
import 'package:bloop/services/storage_service.dart';
import 'package:bloop/ui/screens/permission_settings_screen.dart';
import 'package:bloop/ui/screens/settings_screen.dart';
import 'package:bloop/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runs the screen against real storage held in memory: file I/O never
/// completes under the fake clock widget tests run on.
void main() {
  final storage = StorageService.instance;

  setUpAll(() async {
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

  late ProviderContainer container;

  // The tag manager has a field of its own on the page behind any dialog.
  final dialogField = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );

  SettingsState settings() => container.read(settingsProvider);

  setUp(() async {
    await Hive.box<Task>(StorageService.tasksBoxName).clear();
    await Hive.box<String>(StorageService.tagsBoxName).clear();
    await Hive.box(StorageService.settingsBoxName).clear();
    await storage.addTag('college');
  });

  Future<void> openAdvanced(WidgetTester tester) async {
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, {bool advanced = false}) async {
    tester.view.physicalSize = const Size(1200, 9600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [settingsProvider.overrideWith((ref) => SettingsNotifier())],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light, home: const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    if (advanced) await openAdvanced(tester);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the four groups and keeps the rest under Advanced', (
    tester,
  ) async {
    await open(tester);

    for (final label in ['PROFILE', 'FOCUS', 'TAGS', 'NOTIFICATIONS']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Advanced'), findsOneWidget);
    expect(find.text('Theme'), findsNothing);
    expect(find.text('Reset to defaults'), findsNothing);

    await openAdvanced(tester);

    for (final title in [
      'Theme',
      'Full-screen focus mode',
      'App pinning',
      'Allow overrides during focus',
      'Default reminder',
      'Default task time',
      'Default priority',
      'Export data',
      'Import data',
      'Add demo tasks',
      'Clear all tasks',
      'Reset to defaults',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    // The accent colour picker is hidden for the monochrome 2.0 build.
    expect(find.textContaining('Accent'), findsNothing);
  });

  testWidgets('setting your name drives the greeting name', (tester) async {
    await open(tester);
    expect(find.text('Not set'), findsOneWidget);

    await tapText(tester, 'Your name');
    await tester.enterText(dialogField, '  Saad ');
    await tapText(tester, 'Save');

    expect(settings().userName, 'Saad');
    expect(find.text('Saad'), findsOneWidget);
  });

  testWidgets('cancelling the name dialog keeps the name', (tester) async {
    await open(tester);
    container.read(settingsProvider.notifier).setUserName('Saad');
    await tester.pump();

    await tapText(tester, 'Your name');
    await tester.enterText(dialogField, 'Someone else');
    await tapText(tester, 'Cancel');

    expect(settings().userName, 'Saad');
  });

  testWidgets('clearing the name empties it', (tester) async {
    await open(tester);
    container.read(settingsProvider.notifier).setUserName('Saad');
    await tester.pump();

    await tapText(tester, 'Your name');
    await tester.enterText(dialogField, '');
    await tapText(tester, 'Save');

    expect(settings().userName, '');
    expect(find.text('Not set'), findsOneWidget);
  });

  testWidgets('picks a preset focus length', (tester) async {
    await open(tester);
    expect(settings().defaultFocusMinutes, 25);

    await tapText(tester, '45 min');
    expect(settings().defaultFocusMinutes, 45);

    await tapText(tester, '15 min');
    expect(settings().defaultFocusMinutes, 15);
  });

  testWidgets('Custom asks for a length and rejects values out of range', (
    tester,
  ) async {
    await open(tester);

    await tapText(tester, 'Custom');
    await tester.enterText(dialogField, '0');
    await tapText(tester, 'Save');
    expect(find.text('Enter a number from 1 to 180'), findsOneWidget);

    await tester.enterText(dialogField, '181');
    await tapText(tester, 'Save');
    expect(find.text('Enter a number from 1 to 180'), findsOneWidget);
    expect(settings().defaultFocusMinutes, 25);

    await tester.enterText(dialogField, '30');
    await tapText(tester, 'Save');

    expect(settings().defaultFocusMinutes, 30);
    expect(find.textContaining('Custom: 30 min'), findsOneWidget);
  });

  testWidgets('cancelling Custom leaves the length alone', (tester) async {
    await open(tester);

    await tapText(tester, 'Custom');
    await tapText(tester, 'Cancel');

    expect(settings().defaultFocusMinutes, 25);
  });

  testWidgets('a saved custom length shows Custom selected', (tester) async {
    await open(tester);
    container.read(settingsProvider.notifier).setDefaultFocusMinutes(50);
    await tester.pump();

    expect(find.textContaining('Custom: 50 min'), findsOneWidget);
  });

  testWidgets('lists tags with their open count', (tester) async {
    await storage.upsert(Task(title: 'a', tags: ['college']));
    await open(tester);

    expect(find.textContaining('college'), findsOneWidget);
    expect(find.textContaining('1 open'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
  });

  testWidgets('tags can be added from Settings', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextField), 'research');
    await tapText(tester, 'Add');

    expect(storage.getTags(), ['college', 'research']);
    expect(find.textContaining('research'), findsOneWidget);
  });

  testWidgets('reminder permissions opens the permissions screen', (
    tester,
  ) async {
    await open(tester);

    await tapText(tester, 'Reminder permissions');

    expect(find.byType(PermissionSettingsScreen), findsOneWidget);
    expect(find.text('Exact alarms'), findsOneWidget);
  });

  testWidgets('notification toggles save', (tester) async {
    await open(tester);

    await tapText(tester, 'Task reminders');
    expect(settings().notificationsEnabled, isFalse);

    await tapText(tester, 'Focus session notification');
    expect(settings().focusSessionNotificationsEnabled, isTrue);
  });

  testWidgets('theme, focus behaviour and default priority save', (
    tester,
  ) async {
    await open(tester, advanced: true);

    await tapText(tester, 'Dark');
    expect(settings().themeMode, ThemeMode.dark);

    await tapText(tester, 'Full-screen focus mode');
    expect(settings().focusFullScreenEnabled, isFalse);
    await tapText(tester, 'App pinning');
    expect(settings().focusAppPinningEnabled, isFalse);
    await tapText(tester, 'Allow overrides during focus');
    expect(settings().focusAllowOverrides, isFalse);

    await tapText(tester, 'High');
    expect(settings().defaultPriority, Priority.high);
  });

  testWidgets('default reminder and task time are validated and saved', (
    tester,
  ) async {
    await open(tester, advanced: true);

    await tapText(tester, 'Default reminder');
    await tester.enterText(dialogField, '2000');
    await tapText(tester, 'Save');
    expect(find.text('Enter a number from 0 to 1440'), findsOneWidget);
    await tester.enterText(dialogField, '10');
    await tapText(tester, 'Save');
    expect(settings().defaultReminderMinutes, 10);
    expect(find.text('10 minutes before'), findsOneWidget);

    await tapText(tester, 'Default task time');
    await tester.enterText(dialogField, '90');
    await tapText(tester, 'Save');
    expect(settings().defaultTaskTimeOffsetMinutes, 90);
  });

  testWidgets('export copies the tasks as JSON', (tester) async {
    await storage.upsert(Task(title: 'exported task'));
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await open(tester, advanced: true);

    await tapText(tester, 'Export data');

    expect(copied, contains('exported task'));
    expect(find.text('Exported to clipboard'), findsOneWidget);
  });

  testWidgets('import restores tasks from pasted JSON', (tester) async {
    final json = Task(title: 'imported task').toJson();
    await open(tester, advanced: true);

    await tapText(tester, 'Import data');
    await tester.enterText(dialogField, '[${_encode(json)}]');
    await tapText(tester, 'Import');

    expect(storage.getAll().map((t) => t.title), ['imported task']);
    expect(find.text('Import completed'), findsOneWidget);
  });

  testWidgets('import says so when the JSON is not usable', (tester) async {
    await storage.upsert(Task(title: 'existing'));
    await open(tester, advanced: true);

    await tapText(tester, 'Import data');
    await tester.enterText(dialogField, 'not json');
    await tapText(tester, 'Import');

    expect(find.text('Could not import that JSON'), findsOneWidget);
    expect(find.text('Import completed'), findsNothing);
    expect(container.read(taskListProvider).hasError, isFalse);
    expect(storage.getAll().map((t) => t.title), ['existing']);
  });

  testWidgets('clear all tasks asks first, then deletes', (tester) async {
    await storage.upsert(Task(title: 'a'));
    await open(tester, advanced: true);

    await tapText(tester, 'Clear all tasks');
    await tapText(tester, 'Cancel');
    expect(storage.getAll(), hasLength(1));

    await tapText(tester, 'Clear all tasks');
    await tapText(tester, 'Clear');
    expect(storage.getAll(), isEmpty);
    expect(find.text('All tasks cleared'), findsOneWidget);
  });

  testWidgets('the new Focus screen is off until switched on, and saves', (
    tester,
  ) async {
    await open(tester);
    expect(settings().focusV2Enabled, isFalse);

    await tapText(tester, 'New Focus screen');
    expect(settings().focusV2Enabled, isTrue);
    expect(
      Hive.box(StorageService.settingsBoxName).get('focusV2Enabled'),
      isTrue,
    );

    await tapText(tester, 'New Focus screen');
    expect(settings().focusV2Enabled, isFalse);
  });

  testWidgets('reset asks first, then restores every setting', (tester) async {
    await open(tester, advanced: true);
    final notifier = container.read(settingsProvider.notifier)
      ..setUserName('Saad')
      ..setDefaultFocusMinutes(45)
      ..setFocusV2Enabled(true)
      ..setThemeMode(ThemeMode.dark);
    await tester.pump();

    await tapText(tester, 'Reset to defaults');
    await tapText(tester, 'Cancel');
    expect(settings().userName, 'Saad');

    await tapText(tester, 'Reset to defaults');
    await tapText(tester, 'Reset');

    expect(notifier.state.userName, '');
    expect(settings().defaultFocusMinutes, 25);
    expect(settings().focusV2Enabled, isFalse);
    expect(settings().themeMode, ThemeMode.system);
    expect(find.text('Settings reset to defaults'), findsOneWidget);
  });
}

String _encode(Map<String, dynamic> json) => jsonEncode(json);
