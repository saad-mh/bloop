import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Start of the current local day. Changes at midnight and when the app comes
/// back to the foreground on a later day, so anything grouped by date can
/// watch it instead of polling.
final dayProvider = StateNotifierProvider<DayNotifier, DateTime>(
  (ref) => DayNotifier(),
);

class DayNotifier extends StateNotifier<DateTime> with WidgetsBindingObserver {
  DayNotifier({DateTime Function() now = DateTime.now})
    : _now = now,
      super(_startOfDay(now())) {
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
  }

  final DateTime Function() _now;
  Timer? _timer;

  static DateTime _startOfDay(DateTime t) => DateTime(t.year, t.month, t.day);

  void _scheduleMidnight() {
    _timer?.cancel();
    final nextMidnight = DateTime(state.year, state.month, state.day + 1);
    _timer = Timer(nextMidnight.difference(_now()), _refresh);
  }

  void _refresh() {
    final today = _startOfDay(_now());
    if (today != state) state = today;
    _scheduleMidnight();
  }

  // Timers do not run while the app is suspended, so a night spent in the
  // background leaves the midnight timer unfired.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
