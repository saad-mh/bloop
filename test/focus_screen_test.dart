import 'package:bloop/ui/screens/focus_controller.dart';
import 'package:bloop/ui/screens/focus_widgets.dart';
import 'package:bloop/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the real controller, which needs the audio and notification
/// plugins.
class _FakeFocus extends ChangeNotifier implements FocusController {
  bool fullScreen = false;
  bool running = false;
  bool active = false;
  bool dim = false;
  bool scenery = true;
  String? task;
  String sound = 'Soft Chime';
  String sceneryName = 'Aurora';
  Duration left = const Duration(minutes: 25);
  int started = 0;
  int paused = 0;
  int resets = 0;
  final pickedScenery = <String>[];

  @override
  bool get isInitializing => false;
  @override
  bool get isFullScreenActive => fullScreen;
  @override
  bool get isRunning => running;
  @override
  bool get isSessionActive => active;
  @override
  bool get isFocusSession => true;
  @override
  bool get dimScreenEnabled => dim;
  @override
  bool get sceneryEnabled => scenery;
  @override
  bool get soundsEnabled => true;
  @override
  String? get taskTitle => task;
  @override
  String get selectedSound => sound;
  @override
  String get selectedScenery => sceneryName;
  @override
  Duration get remaining => left;
  @override
  Duration get focusDuration => const Duration(minutes: 25);
  @override
  Duration get shortBreakDuration => const Duration(minutes: 5);
  @override
  Duration get longBreakDuration => const Duration(minutes: 15);
  @override
  Duration get totalFocusSpent => const Duration(minutes: 50);
  @override
  int get totalSessions => 4;
  @override
  int get sessionIndex => 2;
  @override
  bool get autoStartNext => true;
  @override
  double get progress => 0.25;
  @override
  String get sessionLabel => 'Focus';
  @override
  String get focusHintText => task == null
      ? 'Focus on one task for 25 minutes'
      : 'Focus on "$task" for 25 minutes';

  @override
  void start() {
    started++;
    running = true;
    active = true;
    notifyListeners();
  }

  @override
  void pause() {
    paused++;
    running = false;
    notifyListeners();
  }

  @override
  void reset() {
    resets++;
    running = false;
    active = false;
    notifyListeners();
  }

  @override
  void setSelectedScenery(String value) {
    pickedScenery.add(value);
    sceneryName = value;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    _FakeFocus focus, {
    bool dark = false,
  }) async {
    // Phone-sized surface, as the app is designed for.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [focusControllerProvider.overrideWith((ref) => focus)],
        child: MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          home: const Scaffold(body: PomodoroCard()),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
  }

  group('between sessions', () {
    testWidgets('shows the header, time, Start and today total', (
      tester,
    ) async {
      await pumpCard(tester, _FakeFocus());

      expect(find.text('Focus'), findsWidgets);
      expect(find.text('25:00'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Focused today'), findsOneWidget);
      expect(find.text('50m'), findsOneWidget);
      expect(find.byTooltip('Timer settings'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Start starts the timer', (tester) async {
      final focus = _FakeFocus();
      await pumpCard(tester, focus);

      await tester.tap(find.text('Start'));
      await tester.pump();

      expect(focus.started, 1);
      expect(find.text('Pause'), findsOneWidget);
    });

    testWidgets('a paused session offers Resume and says Paused', (
      tester,
    ) async {
      final focus = _FakeFocus()
        ..active = true
        ..left = const Duration(minutes: 18, seconds: 42);
      await pumpCard(tester, focus);

      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('18:42'), findsOneWidget);
    });

    testWidgets('Reset resets the session', (tester) async {
      final focus = _FakeFocus();
      await pumpCard(tester, focus);

      await tester.tap(find.text('Reset'));
      await tester.pump();

      expect(focus.resets, 1);
    });

    testWidgets('names the task a session was started from', (tester) async {
      final focus = _FakeFocus()
        ..active = true
        ..task = 'Robotics Club budget sheet';
      await pumpCard(tester, focus);

      expect(find.text('FOCUSING ON'), findsOneWidget);
      expect(find.text('Robotics Club budget sheet'), findsOneWidget);
    });

    testWidgets('fits a small phone in both themes without overflow', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        tester.view.physicalSize = const Size(720, 1280);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              focusControllerProvider.overrideWith((ref) => _FakeFocus()),
            ],
            child: MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              home: const Scaffold(body: PomodoroCard()),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('running full screen', () {
    _FakeFocus session() => _FakeFocus()
      ..fullScreen = true
      ..running = true
      ..active = true
      ..left = const Duration(minutes: 18, seconds: 42);

    testWidgets('shows only the time and a hint until tapped', (tester) async {
      await pumpCard(tester, session());

      expect(find.text('18:42'), findsOneWidget);
      expect(find.text('SESSION 2 OF 4'), findsOneWidget);
      expect(find.textContaining('Tap to show controls'), findsOneWidget);
      // Controls are laid out but hidden from touch and from screen readers.
      expect(find.text('Pause').hitTestable(), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping shows Pause and the sound and scenery chips', (
      tester,
    ) async {
      final focus = session();
      await pumpCard(tester, focus);

      await tester.tapAt(const Offset(200, 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Sound'), findsOneWidget);
      expect(find.text('Scenery'), findsOneWidget);
      expect(find.text('Slide to end session'), findsOneWidget);

      await tester.tap(find.text('Pause'));
      await tester.pump();
      expect(focus.paused, 1);

      // Let the auto-hide timer run out.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('the scenery picker marks the current one and picks another', (
      tester,
    ) async {
      final focus = session();
      await pumpCard(tester, focus);

      await tester.tapAt(const Offset(200, 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Scenery'));
      await tester.pumpAndSettle();

      expect(find.text('Change scenery'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.text('Moonlight'));
      await tester.pumpAndSettle();

      expect(focus.pickedScenery, ['Moonlight']);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('names the task instead of repeating the hint', (tester) async {
      final focus = session()..task = 'Robotics Club budget sheet';
      await pumpCard(tester, focus);

      expect(find.text('Robotics Club budget sheet'), findsOneWidget);
      expect(find.textContaining('Focus on'), findsNothing);
    });

    testWidgets('builds with scenery and dimming off, in the dark theme', (
      tester,
    ) async {
      final focus = session()
        ..scenery = false
        ..dim = false;
      await pumpCard(tester, focus, dark: true);

      expect(find.text('18:42'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
