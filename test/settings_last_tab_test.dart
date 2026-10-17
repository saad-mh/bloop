import 'dart:io';

import 'package:bloop/providers/settings_provider.dart';
import 'package:bloop/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory dir;
  late Box box;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('bloop_settings_test');
    Hive.init(dir.path);
    box = await Hive.openBox(StorageService.settingsBoxName);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('ignores the tab index saved by the old four-tab bar', () async {
    // 1 was Completed and 2 was Focus there; neither maps to a current tab.
    await box.put('lastTabIndex', 2);

    expect(SettingsNotifier().state.lastTabIndex, 0);
  });

  test('saves and restores the selected tab', () async {
    SettingsNotifier().setLastTabIndex(1);
    await box.flush();

    expect(SettingsNotifier().state.lastTabIndex, 1);
  });
}
