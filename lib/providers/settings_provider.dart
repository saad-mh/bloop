import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import '../services/focus_foreground_task.dart';
import '../services/storage_service.dart';

class SettingsState {
  const SettingsState({
    this.defaultReminderMinutes = 30,
    this.defaultTaskTimeOffsetMinutes = 60,
    this.defaultPriority = Priority.medium,
    this.notificationsEnabled = true,
    this.focusSessionNotificationsEnabled = false,
    this.focusFullScreenEnabled = true,
    this.focusAppPinningEnabled = true,
    this.focusAllowOverrides = true,
    this.themeMode = ThemeMode.system,
    this.seedColor = 0xFF607D8B, // blueGrey
    this.lastTabIndex = 0,
  });

  final int defaultReminderMinutes;
  final int defaultTaskTimeOffsetMinutes;
  final Priority defaultPriority;
  final bool notificationsEnabled;
  final bool focusSessionNotificationsEnabled;
  final bool focusFullScreenEnabled;
  final bool focusAppPinningEnabled;
  final bool focusAllowOverrides;
  final ThemeMode themeMode;
  final int seedColor;
  final int lastTabIndex;

  SettingsState copyWith({
    int? defaultReminderMinutes,
    int? defaultTaskTimeOffsetMinutes,
    Priority? defaultPriority,
    bool? notificationsEnabled,
    bool? focusSessionNotificationsEnabled,
    bool? focusFullScreenEnabled,
    bool? focusAppPinningEnabled,
    bool? focusAllowOverrides,
    ThemeMode? themeMode,
    int? seedColor,
    int? lastTabIndex,
  }) {
    return SettingsState(
      defaultReminderMinutes:
          defaultReminderMinutes ?? this.defaultReminderMinutes,
      defaultTaskTimeOffsetMinutes:
          defaultTaskTimeOffsetMinutes ?? this.defaultTaskTimeOffsetMinutes,
      defaultPriority: defaultPriority ?? this.defaultPriority,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      focusSessionNotificationsEnabled:
          focusSessionNotificationsEnabled ?? this.focusSessionNotificationsEnabled,
      focusFullScreenEnabled:
          focusFullScreenEnabled ?? this.focusFullScreenEnabled,
      focusAppPinningEnabled:
          focusAppPinningEnabled ?? this.focusAppPinningEnabled,
      focusAllowOverrides: focusAllowOverrides ?? this.focusAllowOverrides,
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
      final defaultTaskTimeOffset =
          box.get('defaultTaskTimeOffsetMinutes') as int?;
      final defaultPriorityIndex = box.get('defaultPriority') as int?;
      final notificationsEnabled = box.get('notificationsEnabled') as bool?;
        final focusSessionNotificationsEnabled =
          box.get('focusSessionNotificationsEnabled') as bool?;
        final focusFullScreenEnabled =
          box.get('focusFullScreenEnabled') as bool?;
        final focusAppPinningEnabled =
          box.get('focusAppPinningEnabled') as bool?;
        final focusAllowOverrides = box.get('focusAllowOverrides') as bool?;
      final themeModeIndex = box.get('themeMode') as int?;
      final seed = box.get('seedColor') as int?;

      state = state.copyWith(
        defaultReminderMinutes: defaultReminder ?? state.defaultReminderMinutes,
        defaultTaskTimeOffsetMinutes:
            defaultTaskTimeOffset ?? state.defaultTaskTimeOffsetMinutes,
        defaultPriority: (defaultPriorityIndex != null && defaultPriorityIndex >= 0 && defaultPriorityIndex < Priority.values.length)
            ? Priority.values[defaultPriorityIndex]
            : state.defaultPriority,
        notificationsEnabled: notificationsEnabled ?? state.notificationsEnabled,
        focusSessionNotificationsEnabled:
          focusSessionNotificationsEnabled ?? state.focusSessionNotificationsEnabled,
        focusFullScreenEnabled:
          focusFullScreenEnabled ?? state.focusFullScreenEnabled,
        focusAppPinningEnabled:
          focusAppPinningEnabled ?? state.focusAppPinningEnabled,
        focusAllowOverrides: focusAllowOverrides ?? state.focusAllowOverrides,
        themeMode: themeModeIndex != null && themeModeIndex >= 0 && themeModeIndex < ThemeMode.values.length
            ? ThemeMode.values[themeModeIndex]
            : state.themeMode,
        seedColor: seed ?? state.seedColor,
        lastTabIndex: box.get('lastTabIndex') as int? ?? state.lastTabIndex,
      );
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool(
          FocusSessionPrefs.focusNotificationsEnabledKey,
          state.focusSessionNotificationsEnabled,
        );
      });
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

  void setDefaultTaskTimeOffsetMinutes(int minutes) {
    state = state.copyWith(defaultTaskTimeOffsetMinutes: minutes);
    try {
      final box = Hive.box(StorageService.settingsBoxName);
      box.put('defaultTaskTimeOffsetMinutes', minutes);
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

  void setFocusSessionNotificationsEnabled(bool value) {
    state = state.copyWith(focusSessionNotificationsEnabled: value);
    try {
      final box = Hive.box(StorageService.settingsBoxName);
      box.put('focusSessionNotificationsEnabled', value);
    } catch (_) {}
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(FocusSessionPrefs.focusNotificationsEnabledKey, value);
    });
  }

  void setFocusFullScreenEnabled(bool value) {
    state = state.copyWith(focusFullScreenEnabled: value);
    try {
      final box = Hive.box(StorageService.settingsBoxName);
      box.put('focusFullScreenEnabled', value);
    } catch (_) {}
  }

  void setFocusAppPinningEnabled(bool value) {
    state = state.copyWith(focusAppPinningEnabled: value);
    try {
      final box = Hive.box(StorageService.settingsBoxName);
      box.put('focusAppPinningEnabled', value);
    } catch (_) {}
  }

  void setFocusAllowOverrides(bool value) {
    state = state.copyWith(focusAllowOverrides: value);
    try {
      final box = Hive.box(StorageService.settingsBoxName);
      box.put('focusAllowOverrides', value);
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
