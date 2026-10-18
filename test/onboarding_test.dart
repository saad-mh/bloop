import 'dart:typed_data';

import 'package:bloop/models/task.dart';
import 'package:bloop/providers/onboarding_provider.dart';
import 'package:bloop/providers/settings_provider.dart';
import 'package:bloop/providers/task_provider.dart';
import 'package:bloop/services/storage_service.dart';
import 'package:bloop/ui/screens/home_screen.dart';
import 'package:bloop/ui/screens/onboarding_gate.dart';
import 'package:bloop/ui/screens/onboarding_screen.dart';
import 'package:bloop/ui/theme/app_theme.dart';
import 'package:bloop/ui/widgets/example_task_confetti.dart';
import 'package:bloop/ui/widgets/tag_pill.dart';
import 'package:bloop/ui/widgets/task_tile.dart';
import 'package:bloop/utils/onboarding_content.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Lets a test put the task list in any state without touching storage.
class _Tasks extends TaskNotifier {
  @override
  Future<void> load() async {}

  void show(List<Task> tasks) => state = AsyncData(tasks);
}

/// Finish always fails, as when storage is unwritable.
class _FailingOnboarding extends OnboardingNotifier {
  _FailingOnboarding(super.ref);

  @override
  Future<bool> finish({String name = '', List<String> tags = const []}) async =>
      false;
}

/// Runs against real storage held in memory: file I/O never completes under
/// the fake clock widget tests run on.
void main() {
  final storage = StorageService.instance;

  late Box<Task> tasksBox;
  late Box<String> tagsBox;
  late Box settingsBox;

  setUpAll(() async {
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(PriorityAdapter());
    Hive.registerAdapter(RecurrenceAdapter());
    tasksBox = await Hive.openBox<Task>(
      StorageService.tasksBoxName,
      bytes: Uint8List(0),
    );
    tagsBox = await Hive.openBox<String>(
      StorageService.tagsBoxName,
      bytes: Uint8List(0),
    );
    settingsBox = await Hive.openBox(
      StorageService.settingsBoxName,
      bytes: Uint8List(0),
    );
  });

  tearDownAll(() async {
    await Hive.close();
  });

  setUp(() async {
    await tasksBox.clear();
    await tagsBox.clear();
    await settingsBox.clear();
  });

  group('first run detection', () {
    test('a clean install is not done', () {
      expect(storage.isOnboardingComplete(), isFalse);
      expect(settingsBox.get(StorageService.onboardingCompleteKey), isNull);
    });

    test('a stored flag decides', () async {
      await settingsBox.put(StorageService.onboardingCompleteKey, true);
      expect(storage.isOnboardingComplete(), isTrue);
    });

    for (final (name, seed) in <(String, Future<void> Function())>[
      ('a task', () => storage.upsert(Task(title: 'Old task'))),
      ('a tag', () => storage.addTag('work')),
      ('a setting', () => settingsBox.put('themeMode', 1)),
    ]) {
      test('an existing user with $name skips and is remembered', () async {
        await seed();

        expect(storage.isOnboardingComplete(), isTrue);

        await Future<void>.delayed(Duration.zero);
        expect(settingsBox.get(StorageService.onboardingCompleteKey), isTrue);
      });
    }

    test('a completed task alone still counts as an existing user', () async {
      await storage.upsert(Task(title: 'Done', isCompleted: true));

      expect(storage.isOnboardingComplete(), isTrue);
    });
  });

  group('flow', () {
    Future<void> pumpGate(
      WidgetTester tester, {
      List<Override> overrides = const [],
    }) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const OnboardingGate(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapButton(WidgetTester tester, String label) async {
      await tester.tap(
        find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> toTagsStep(WidgetTester tester, {String name = ''}) async {
      if (name.isNotEmpty) {
        await tester.enterText(find.byType(TextField), name);
      }
      await tapButton(tester, 'Next');
    }

    Future<void> addTag(WidgetTester tester, String tag) async {
      await tester.enterText(find.byType(TextField), tag);
      await tapButton(tester, 'Add');
    }

    final onboarding = find.byType(OnboardingScreen);

    testWidgets('a clean install starts with the welcome step', (tester) async {
      await pumpGate(tester);

      expect(onboarding, findsOneWidget);
      expect(find.text('Welcome to Bloop'), findsOneWidget);
      expect(find.text('Step 1 of 2'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('goes straight to Home once the flag is set', (tester) async {
      await settingsBox.put(StorageService.onboardingCompleteKey, true);

      await pumpGate(tester);

      expect(onboarding, findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('an existing user is not shown onboarding', (tester) async {
      await storage.upsert(Task(title: 'Already here'));

      await pumpGate(tester);

      expect(onboarding, findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('the name is trimmed and saved', (tester) async {
      await pumpGate(tester);

      await toTagsStep(tester, name: '  Saad  ');
      await tapButton(tester, 'Finish');

      expect(settingsBox.get('userName'), 'Saad');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      expect(container.read(settingsProvider).userName, 'Saad');
    });

    testWidgets('the name can be skipped', (tester) async {
      await pumpGate(tester);

      await tapButton(tester, 'Skip');
      await tapButton(tester, 'Finish');

      expect(settingsBox.containsKey('userName'), isFalse);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('Skip is not offered once a name is typed', (tester) async {
      await pumpGate(tester);
      expect(find.text('Skip'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Saad');
      await tester.pump();

      expect(find.text('Skip'), findsNothing);
    });

    testWidgets('Next with an empty name also moves on', (tester) async {
      await pumpGate(tester);

      await tapButton(tester, 'Next');

      expect(find.text('Tag your tasks'), findsOneWidget);
      expect(find.text('Step 2 of 2'), findsOneWidget);
    });

    testWidgets('Back returns to the name and keeps it', (tester) async {
      await pumpGate(tester);
      await toTagsStep(tester, name: 'Saad');

      await tapButton(tester, 'Back');

      expect(find.text('Welcome to Bloop'), findsOneWidget);
      expect(find.text('Saad'), findsOneWidget);
    });

    testWidgets('the system back gesture steps back instead of leaving', (
      tester,
    ) async {
      await pumpGate(tester);
      await toTagsStep(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Welcome to Bloop'), findsOneWidget);
      expect(onboarding, findsOneWidget);
    });

    group('small screen with the keyboard open', () {
      // A 320x568dp phone with a 270dp keyboard.
      const keyboard = 270.0;
      const visibleBottom = 568.0 - keyboard;

      Future<void> openKeyboard(WidgetTester tester) async {
        tester.view.physicalSize = const Size(960, 1704);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.tap(find.byType(TextField));
        tester.view.viewInsets = const FakeViewPadding(bottom: keyboard * 3);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
      }

      Finder nextButton(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      );

      testWidgets('the name field and Next stay above it', (tester) async {
        await pumpGate(tester);

        await openKeyboard(tester);

        expect(
          tester.getRect(find.byType(TextField)).bottom,
          lessThanOrEqualTo(visibleBottom),
        );
        expect(
          tester.getRect(nextButton('Next')).bottom,
          lessThanOrEqualTo(visibleBottom),
        );
      });

      testWidgets('the tag field and Finish stay above it', (tester) async {
        await pumpGate(tester);
        await toTagsStep(tester);

        await openKeyboard(tester);

        expect(
          tester.getRect(find.byType(TextField)).bottom,
          lessThanOrEqualTo(visibleBottom),
        );
        expect(
          tester.getRect(nextButton('Finish')).bottom,
          lessThanOrEqualTo(visibleBottom),
        );
        expect(tester.takeException(), isNull);
      });
    });

    group('tags', () {
      testWidgets('an empty name is refused', (tester) async {
        await pumpGate(tester);
        await toTagsStep(tester);

        await tapButton(tester, 'Add');

        expect(find.text('Enter a name for the tag'), findsOneWidget);
      });

      testWidgets('a duplicate is refused, ignoring case and spaces', (
        tester,
      ) async {
        await pumpGate(tester);
        await toTagsStep(tester);
        await addTag(tester, 'gym');

        await addTag(tester, '  GYM ');

        expect(
          find.text('A tag with that name already exists'),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('tag-gym')), findsOneWidget);
      });

      testWidgets('the error clears as soon as the text changes', (
        tester,
      ) async {
        await pumpGate(tester);
        await toTagsStep(tester);
        await tapButton(tester, 'Add');

        await tester.enterText(find.byType(TextField), 'g');
        await tester.pump();

        expect(find.text('Enter a name for the tag'), findsNothing);
      });

      testWidgets('a typed tag is added trimmed and the field clears', (
        tester,
      ) async {
        await pumpGate(tester);
        await toTagsStep(tester);

        await addTag(tester, '  gym ');

        expect(find.byKey(const ValueKey('tag-gym')), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
      });

      testWidgets('the field keeps focus so the next tag can be typed', (
        tester,
      ) async {
        await pumpGate(tester);
        await toTagsStep(tester);

        await tester.enterText(find.byType(TextField), 'gym');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('tag-gym')), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
          isTrue,
        );
      });

      testWidgets('a suggestion adds a tag and leaves the suggestions', (
        tester,
      ) async {
        await pumpGate(tester);
        await toTagsStep(tester);
        expect(
          find.byKey(const ValueKey('suggestion-college')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('suggestion-college')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('tag-college')), findsOneWidget);
        expect(find.byKey(const ValueKey('suggestion-college')), findsNothing);
        expect(find.byKey(const ValueKey('suggestion-work')), findsOneWidget);
      });

      testWidgets('a typed tag that matches a suggestion hides it', (
        tester,
      ) async {
        await pumpGate(tester);
        await toTagsStep(tester);

        await addTag(tester, 'Work');

        expect(find.byKey(const ValueKey('suggestion-work')), findsNothing);
      });

      testWidgets('a tag can be removed', (tester) async {
        await pumpGate(tester);
        await toTagsStep(tester);
        await addTag(tester, 'gym');

        await tester.tap(find.byTooltip('Remove gym'));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('tag-gym')), findsNothing);
      });
    });

    group('preview', () {
      Finder previewPills() => find.descendant(
        of: find.byType(TaskTile),
        matching: find.byType(TagPill),
      );

      testWidgets('shows example tags until the user adds one', (tester) async {
        await pumpGate(tester);
        await toTagsStep(tester);

        expect(find.byType(TaskTile), findsNWidgets(3));
        expect(find.text('What tags look like'), findsOneWidget);
        for (final tag in suggestedTags) {
          expect(
            find.descendant(of: previewPills(), matching: find.text(tag)),
            findsOneWidget,
          );
        }
      });

      testWidgets('puts a different tag of the user on each row', (
        tester,
      ) async {
        await pumpGate(tester);
        await toTagsStep(tester);
        await addTag(tester, 'gym');
        await addTag(tester, 'home');
        await addTag(tester, 'errands');

        expect(find.text('Your tags on tasks'), findsOneWidget);
        expect(previewPills(), findsNWidgets(3));
        for (final tag in ['gym', 'home', 'errands']) {
          expect(
            find.descendant(of: previewPills(), matching: find.text(tag)),
            findsOneWidget,
          );
        }
        // The examples are gone.
        expect(
          find.descendant(of: previewPills(), matching: find.text('college')),
          findsNothing,
        );
      });

      testWidgets('leaves spare rows untagged', (tester) async {
        await pumpGate(tester);
        await toTagsStep(tester);

        await addTag(tester, 'gym');

        expect(find.byType(TaskTile), findsNWidgets(3));
        expect(previewPills(), findsOneWidget);
      });

      testWidgets('shows the newest tags when there are more than rows', (
        tester,
      ) async {
        await pumpGate(tester);
        await toTagsStep(tester);
        for (final tag in ['a', 'b', 'c', 'd']) {
          await addTag(tester, tag);
        }

        final shown = tester
            .widgetList<TagPill>(previewPills())
            .map((p) => p.label)
            .toList();
        expect(shown, ['b', 'c', 'd']);
      });

      testWidgets('is not interactive', (tester) async {
        await pumpGate(tester);
        await toTagsStep(tester);

        final circle = find.descendant(
          of: find.byType(TaskTile).first,
          matching: find.byType(InkResponse),
        );
        await tester.tap(circle, warnIfMissed: false);
        await tester.pumpAndSettle();

        // Still onboarding, with nothing saved or completed.
        expect(onboarding, findsOneWidget);
        expect(tasksBox, isEmpty);
      });
    });

    group('finishing', () {
      testWidgets('saves the tags, adds the example and lands on Home', (
        tester,
      ) async {
        await pumpGate(tester);
        await toTagsStep(tester, name: 'Saad');
        await addTag(tester, 'gym');
        await addTag(tester, 'home');

        await tapButton(tester, 'Finish');

        expect(onboarding, findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.text(exampleTaskTitle), findsOneWidget);

        // Real tags, so Settings and the task editor list them.
        expect(storage.getTags(), ['gym', 'home']);
        expect(settingsBox.get(StorageService.onboardingCompleteKey), isTrue);
        final example = storage.getAll().single;
        expect(example.title, exampleTaskTitle);
        expect(example.tags, ['gym']);
        expect(example.isCompleted, isFalse);
        expect(storage.onboardingExampleTaskId, example.id);
      });

      testWidgets('the example sits at the top of Home, due now', (
        tester,
      ) async {
        await pumpGate(tester);
        await tapButton(tester, 'Next');
        await tapButton(tester, 'Finish');

        expect(find.text('NOW'), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);
      });

      testWidgets('Skip tags is not offered once a tag is added', (
        tester,
      ) async {
        await pumpGate(tester);
        await toTagsStep(tester);
        expect(find.text('Skip tags'), findsOneWidget);

        await addTag(tester, 'gym');

        // Skipping would throw the tag away, so only Finish remains.
        expect(find.text('Skip tags'), findsNothing);
      });

      testWidgets('skipping tags still adds an untagged example', (
        tester,
      ) async {
        await pumpGate(tester);
        await toTagsStep(tester);

        await tapButton(tester, 'Skip tags');

        expect(find.text(exampleTaskTitle), findsOneWidget);
        expect(storage.getTags(), isEmpty);
        expect(storage.getAll().single.tags, isEmpty);
      });

      testWidgets('skipping everything leaves a valid app', (tester) async {
        await pumpGate(tester);

        await tapButton(tester, 'Skip');
        await tapButton(tester, 'Skip tags');

        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.text(exampleTaskTitle), findsOneWidget);
        expect(settingsBox.get(StorageService.onboardingCompleteKey), isTrue);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a tag typed but not added is still saved', (tester) async {
        await pumpGate(tester);
        await toTagsStep(tester);

        await tester.enterText(find.byType(TextField), '  gym ');
        await tapButton(tester, 'Finish');

        expect(storage.getTags(), ['gym']);
        expect(storage.getAll().single.tags, ['gym']);
      });

      testWidgets('a typed tag that is refused stops Finish and says why', (
        tester,
      ) async {
        await pumpGate(tester);
        await toTagsStep(tester);
        await addTag(tester, 'gym');

        await tester.enterText(find.byType(TextField), 'GYM');
        await tapButton(tester, 'Finish');

        expect(
          find.text('A tag with that name already exists'),
          findsOneWidget,
        );
        expect(onboarding, findsOneWidget);
        expect(tasksBox, isEmpty);
      });

      testWidgets('is not shown again on the next launch', (tester) async {
        await pumpGate(tester);
        await tapButton(tester, 'Next');
        await tapButton(tester, 'Finish');

        // A new app, as after a restart.
        await tester.pumpWidget(const SizedBox());
        await pumpGate(tester);

        expect(onboarding, findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
      });

      testWidgets('quitting halfway saves nothing, so it starts over', (
        tester,
      ) async {
        await pumpGate(tester);
        await toTagsStep(tester, name: 'Saad');
        await addTag(tester, 'gym');

        await tester.pumpWidget(const SizedBox());
        await pumpGate(tester);

        expect(onboarding, findsOneWidget);
        expect(storage.getTags(), isEmpty);
        expect(tasksBox, isEmpty);
      });

      testWidgets('a failure stays put, says so and can be retried', (
        tester,
      ) async {
        await pumpGate(
          tester,
          overrides: [
            onboardingProvider.overrideWith((ref) => _FailingOnboarding(ref)),
          ],
        );
        await tapButton(tester, 'Next');

        await tapButton(tester, 'Finish');

        expect(onboarding, findsOneWidget);
        expect(
          find.text('Could not finish setting up. Try again.'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, 'Finish'))
              .onPressed,
          isNotNull,
        );
      });

      testWidgets('does not ask for notification permission', (tester) async {
        // The example has no reminder, so nothing is scheduled; on Android
        // scheduling is what would trigger the system prompt (#18).
        await pumpGate(tester);
        await tapButton(tester, 'Next');
        await tapButton(tester, 'Finish');

        final example = storage.getAll().single;
        expect(example.remindersBefore, isEmpty);
        expect(example.notificationIds, isNull);
      });
    });

    group('confetti on Home', () {
      testWidgets('shows over the Focus tab too', (tester) async {
        await pumpGate(tester);
        await tapButton(tester, 'Next');
        await tapButton(tester, 'Finish');
        await tester.tap(find.text('Focus'));
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ConfettiWidget)),
        );

        // As when the session on the Focus tab is marked done.
        await container
            .read(taskListProvider.notifier)
            .toggleComplete(storage.getAll().single, value: true);
        await tester.pump();

        expect(
          tester
              .widget<ConfettiWidget>(find.byType(ConfettiWidget))
              .confettiController
              .state,
          ConfettiControllerState.playing,
        );
        await tester.pumpAndSettle();
      });

      testWidgets('completing the example fires confetti, once', (
        tester,
      ) async {
        await pumpGate(tester);
        await tapButton(tester, 'Next');
        await tapButton(tester, 'Finish');
        ConfettiController confetti() => tester
            .widget<ConfettiWidget>(find.byType(ConfettiWidget))
            .confettiController;
        expect(confetti().state, ConfettiControllerState.stopped);

        await tester.tap(
          find.descendant(
            of: find.byType(TaskTile),
            matching: find.byType(InkResponse),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();

        expect(confetti().state, ConfettiControllerState.playing);
        expect(storage.onboardingExampleTaskId, isNull);

        // Let it finish, then do and undo the task: nothing fires again.
        await tester.pumpAndSettle();
        expect(confetti().state, ConfettiControllerState.stopped);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(HomeScreen)),
        );
        final example = storage.getAll().single;
        await container
            .read(taskListProvider.notifier)
            .toggleComplete(example, value: false);
        await container
            .read(taskListProvider.notifier)
            .toggleComplete(example, value: true);
        await tester.pump();
        expect(confetti().state, ConfettiControllerState.stopped);
        await tester.pumpAndSettle();
      });
    });
  });

  group('finish retried', () {
    test('reuses the example an earlier try left behind', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(onboardingProvider.notifier);

      expect(await notifier.finish(), isTrue);
      final first = storage.getAll().single;
      // As if a later step had failed and the user tapped Finish again.
      expect(await notifier.finish(), isTrue);

      expect(storage.getAll().map((t) => t.id), [first.id]);
      expect(storage.onboardingExampleTaskId, first.id);
      expect(container.read(exampleTaskIdProvider), first.id);
    });

    test('makes a new example when the stored one is gone', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(onboardingProvider.notifier);
      await notifier.finish();
      final first = storage.getAll().single;
      await storage.delete(first.id);

      expect(await notifier.finish(), isTrue);

      final second = storage.getAll().single;
      expect(second.id, isNot(first.id));
      expect(storage.onboardingExampleTaskId, second.id);
    });
  });

  group('ExampleTaskConfetti', () {
    final example = Task(id: 'example', title: exampleTaskTitle);
    final other = Task(id: 'other', title: 'Something else');
    late _Tasks tasks;

    Future<ProviderContainer> pumpOverlay(
      WidgetTester tester, {
      bool reduceMotion = false,
      String? exampleId = 'example',
    }) async {
      tasks = _Tasks();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskListProvider.overrideWith((ref) => tasks),
            exampleTaskIdProvider.overrideWith((ref) => exampleId),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduceMotion),
              child: const ExampleTaskConfetti(child: SizedBox.expand()),
            ),
          ),
        ),
      );
      tasks.show([example, other]);
      await tester.pump();
      return ProviderScope.containerOf(
        tester.element(find.byType(ExampleTaskConfetti)),
      );
    }

    ConfettiControllerState state(WidgetTester tester) => tester
        .widget<ConfettiWidget>(find.byType(ConfettiWidget))
        .confettiController
        .state;

    Task done(Task t) => Task(id: t.id, title: t.title, isCompleted: true);

    testWidgets('fires when the example is completed', (tester) async {
      final container = await pumpOverlay(tester);

      tasks.show([done(example), other]);
      await tester.pump();

      expect(state(tester), ConfettiControllerState.playing);
      expect(container.read(exampleTaskIdProvider), isNull);
      await tester.pumpAndSettle();
    });

    testWidgets('stays quiet for any other task', (tester) async {
      final container = await pumpOverlay(tester);

      tasks.show([example, done(other)]);
      await tester.pump();

      expect(state(tester), ConfettiControllerState.stopped);
      expect(container.read(exampleTaskIdProvider), 'example');
    });

    testWidgets('does not fire a second time', (tester) async {
      await pumpOverlay(tester);
      tasks.show([done(example), other]);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(state(tester), ConfettiControllerState.stopped);

      tasks.show([example, other]);
      await tester.pump();
      tasks.show([done(example), other]);
      await tester.pump();

      expect(state(tester), ConfettiControllerState.stopped);
    });

    testWidgets('deleting the example retires it without confetti', (
      tester,
    ) async {
      final container = await pumpOverlay(tester);

      tasks.show([other]);
      await tester.pump();

      expect(state(tester), ConfettiControllerState.stopped);
      expect(container.read(exampleTaskIdProvider), isNull);
    });

    testWidgets('does nothing when there is no example', (tester) async {
      await pumpOverlay(tester, exampleId: null);

      tasks.show([done(other)]);
      await tester.pump();

      expect(state(tester), ConfettiControllerState.stopped);
    });

    testWidgets('reduced motion skips the burst but retires the example', (
      tester,
    ) async {
      final container = await pumpOverlay(tester, reduceMotion: true);

      tasks.show([done(example), other]);
      await tester.pump();

      expect(state(tester), ConfettiControllerState.stopped);
      expect(container.read(exampleTaskIdProvider), isNull);
    });

    testWidgets('does not block touches on what is underneath', (tester) async {
      var taps = 0;
      tasks = _Tasks();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [taskListProvider.overrideWith((ref) => tasks)],
          child: MaterialApp(
            home: ExampleTaskConfetti(
              child: Center(
                child: TextButton(
                  onPressed: () => taps++,
                  child: const Text('Underneath'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Underneath'));

      expect(taps, 1);
    });
  });
}
