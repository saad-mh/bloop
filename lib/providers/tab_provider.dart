import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_provider.dart';

/// Tab positions in the app shell's nav, in order.
const int tasksTabIndex = 0;
const int focusTabIndex = 1;
const int tabCount = 2;

/// The tab on screen. Starts on the one saved last time, and saves each
/// change so the app reopens there.
class TabNotifier extends StateNotifier<int> {
  TabNotifier(this._ref) : super(_saved(_ref));

  final Ref _ref;

  static int _saved(Ref ref) {
    final saved = ref.read(settingsProvider).lastTabIndex;
    return saved >= 0 && saved < tabCount ? saved : tasksTabIndex;
  }

  void select(int index) {
    if (index == state || index < 0 || index >= tabCount) return;
    state = index;
    _ref.read(settingsProvider.notifier).setLastTabIndex(index);
  }
}

final selectedTabProvider = StateNotifierProvider<TabNotifier, int>(
  TabNotifier.new,
);
