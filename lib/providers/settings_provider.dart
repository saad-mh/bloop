import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/task.dart';
import '../services/storage_service.dart';

class SettingsState {
  const SettingsState({
    this.defaultReminderMinutes = 30,
    this.defaultPriority = Priority.medium,
    this.notificationsEnabled = true,
    this.themeMode = ThemeMode.system,
    this.seedColor = 0xFF607D8B, // blueGrey
    this.lastTabIndex = 0,
  });

  final int defaultReminderMinutes;
  final Priority defaultPriority;
  final bool notificationsEnabled;
  final ThemeMode themeMode;
  final int seedColor;
  final int lastTabIndex;

  SettingsState copyWith({
    int? defaultReminderMinutes,
    Priority? defaultPriority,
    bool? notificationsEnabled,
    ThemeMode? themeMode,
    int? seedColor,
    int? lastTabIndex,
  }) {
    return SettingsState(
      defaultReminderMinutes:
          defaultReminderMinutes ?? this.defaultReminderMinutes,
      defaultPriority: defaultPriority ?? this.defaultPriority,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      themeMode: themeMode ?? this.themeMode,
      seedColor: seedColor ?? this.seedColor,
      lastTabIndex: lastTabIndex ?? this.lastTabIndex,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    try {
      final box = Hive.box(StorageService.settingsBoxName);
      final defaultReminder = box.get('defaultReminderMinutes') as int?;
      final defaultPriorityIndex = box.get('defaultPriority') as int?;
      final notificationsEnabled = box.get('notificationsEnabled') as bool?;
      final themeModeIndex = box.get('themeMode') as int?;
      final seed = box.get('seedColor') as int?;

      state = state.copyWith(
        defaultReminderMinutes: defaultReminder ?? state.defaultReminderMinutes,
        defaultPriority: (defaultPriorityIndex != null && defaultPriorityIndex >= 0 && defaultPriorityIndex < Priority.values.length)
            ? Priority.values[defaultPriorityIndex]
            : state.defaultPriority,
        notificationsEnabled: notificationsEnabled ?? state.notificationsEnabled,
        themeMode: themeModeIndex != null && themeModeIndex >= 0 && themeModeIndex < ThemeMode.values.length
            ? ThemeMode.values[themeModeIndex]
            : state.themeMode,
        seedColor: seed ?? state.seedColor,
        lastTabIndex: box.get('lastTabIndex') as int? ?? state.lastTabIndex,
      );
    } catch (_) {
      // ignore errors; defaults will be used
    }
  }

  void setReminderMinutes(int minutes) {
    state = state.copyWith(defaultReminderMinutes: minutes);
    try {
      final box = Hive.box(StorageService.settingsBoxName);
      box.put('defaultReminderMinutes', minutes);
    } catch (_) {}
  }

  void setPriority(Priority priority) {
    state = state.copyWith(defaultPriority: priority);
    try {
      final box = Hive.box(StorageService.settingsBoxName);
      box.put('defaultPriority', priority.index);
    } catch (_) {}
  }

  void setNotificationsEnabled(bool value) {
    state = state.copyWith(notificationsEnabled: value);
    try {
      final box = Hive.box(StorageService.settingsBoxName);
      box.put('notificationsEnabled', value);
    } catch (_) {}
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    try {
      final box = Hive.box(StorageService.settingsBoxName);
      box.put('themeMode', ThemeMode.values.indexOf(mode));
    } catch (_) {}
  }

  void setSeedColor(int colorValue) {
    state = state.copyWith(seedColor: colorValue);
    try {
      final box = Hive.box(StorageService.settingsBoxName);
      box.put('seedColor', colorValue);
    } catch (_) {}
  }

  void setLastTabIndex(int index) {
    state = state.copyWith(lastTabIndex: index);
    try {
      final box = Hive.box(StorageService.settingsBoxName);
      box.put('lastTabIndex', index);
    } catch (_) {}
  }

  void resetDefaults() {
    state = const SettingsState();
    try {
      final box = Hive.box(StorageService.settingsBoxName);
      box.clear();
    } catch (_) {}
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});
