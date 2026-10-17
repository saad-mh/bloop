import 'package:bloop/providers/day_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts at the beginning of the current day', (tester) async {
    final notifier = DayNotifier(now: () => DateTime(2026, 10, 17, 15, 42));

    expect(notifier.state, DateTime(2026, 10, 17));
    notifier.dispose();
  });

  testWidgets('moves to the next day at midnight, and again the day after', (
    tester,
  ) async {
    var clock = DateTime(2026, 10, 17, 23, 0);
    final notifier = DayNotifier(now: () => clock);

    await tester.pump(const Duration(minutes: 59));
    expect(notifier.state, DateTime(2026, 10, 17));

    clock = DateTime(2026, 10, 18, 0, 0, 1);
    await tester.pump(const Duration(minutes: 1, seconds: 1));
    expect(notifier.state, DateTime(2026, 10, 18));

    // The timer was re-armed for the following midnight.
    clock = DateTime(2026, 10, 19, 0, 0, 1);
    await tester.pump(const Duration(hours: 24));
    expect(notifier.state, DateTime(2026, 10, 19));
    notifier.dispose();
  });

  testWidgets('catches up on resume when the timer never fired', (
    tester,
  ) async {
    var clock = DateTime(2026, 10, 17, 23, 0);
    final notifier = DayNotifier(now: () => clock);

    // App suspended overnight: no timer ticks, the clock just moves on.
    clock = DateTime(2026, 10, 18, 7, 30);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    expect(notifier.state, DateTime(2026, 10, 18));
    notifier.dispose();
  });

  testWidgets('resuming on the same day changes nothing', (tester) async {
    final notifier = DayNotifier(now: () => DateTime(2026, 10, 17, 9));
    final seen = <DateTime>[];
    notifier.addListener(seen.add, fireImmediately: false);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    expect(seen, isEmpty);
    notifier.dispose();
  });
}
