import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../providers/settings_provider.dart';
import '../providers/task_provider.dart';

class SettingsScreenController {
  SettingsScreenController(this._ref);

  final Ref _ref;

  List<int> get accentColors => const [
        0xFF607D8B, // Blue Grey
        0xFF3F51B5, // Indigo
        0xFF009688, // Teal
        0xFFFF5722, // Deep Orange
        0xFF9C27B0, // Purple
        0xFF4CAF50, // Green
      ];

  void setThemeMode(ThemeMode mode) {
    _ref.read(settingsProvider.notifier).setThemeMode(mode);
  }

  void setSeedColor(int colorValue) {
    _ref.read(settingsProvider.notifier).setSeedColor(colorValue);
  }

  void setNotificationsEnabled(bool value) {
    _ref.read(settingsProvider.notifier).setNotificationsEnabled(value);
  }

  void setFocusSessionNotificationsEnabled(bool value) {
    _ref.read(settingsProvider.notifier).setFocusSessionNotificationsEnabled(value);
  }

  void setFocusFullScreenEnabled(bool value) {
    _ref.read(settingsProvider.notifier).setFocusFullScreenEnabled(value);
  }

  void setFocusAppPinningEnabled(bool value) {
    _ref.read(settingsProvider.notifier).setFocusAppPinningEnabled(value);
  }

  void setFocusAllowOverrides(bool value) {
    _ref.read(settingsProvider.notifier).setFocusAllowOverrides(value);
  }

  void resetDefaults() {
    _ref.read(settingsProvider.notifier).resetDefaults();
  }

  void setReminderMinutes(int minutes) {
    _ref.read(settingsProvider.notifier).setReminderMinutes(minutes);
  }

  void setDefaultTaskTimeOffsetMinutes(int minutes) {
    _ref
        .read(settingsProvider.notifier)
        .setDefaultTaskTimeOffsetMinutes(minutes);
  }

  void setPriority(Priority priority) {
    _ref.read(settingsProvider.notifier).setPriority(priority);
  }

  Future<void> addDemoTasks() {
    return _ref.read(taskListProvider.notifier).addDemoTasks();
  }

  Future<void> clearAllTasks() {
    return _ref.read(taskListProvider.notifier).clearAll();
  }

  String exportJson() {
    return _ref.read(taskListProvider.notifier).exportJson();
  }

  Future<void> importJson(String json) {
    return _ref.read(taskListProvider.notifier).importJson(json);
  }
}

final settingsScreenControllerProvider = Provider<SettingsScreenController>((ref) {
  return SettingsScreenController(ref);
});
