import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../providers/settings_provider.dart';
import '../providers/tags_provider.dart';
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

  void setUserName(String name) {
    _ref.read(settingsProvider.notifier).setUserName(name);
  }

  void setDefaultFocusMinutes(int minutes) {
    _ref.read(settingsProvider.notifier).setDefaultFocusMinutes(minutes);
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

  Future<void> addDemoTasks() async {
    await _ref.read(taskListProvider.notifier).addDemoTasks();
    await _ref.read(tagsProvider.notifier).load();
  }

  Future<void> clearAllTasks() {
    return _ref.read(taskListProvider.notifier).clearAll();
  }

  String exportJson() {
    return _ref.read(taskListProvider.notifier).exportJson();
  }

  /// Returns whether [json] was imported. A failed import leaves the task
  /// list in an error state, so it is reloaded from storage.
  Future<bool> importJson(String json) async {
    final tasks = _ref.read(taskListProvider.notifier);
    await tasks.importJson(json);
    if (!_ref.read(taskListProvider).hasError) return true;
    await tasks.load();
    return false;
  }
}

final settingsScreenControllerProvider = Provider<SettingsScreenController>((ref) {
  return SettingsScreenController(ref);
});
