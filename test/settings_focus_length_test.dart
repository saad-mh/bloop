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
    dir = await Directory.systemTemp.createTemp('bloop_focus_length_test');
    Hive.init(dir.path);
    box = await Hive.openBox(StorageService.settingsBoxName);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test('defaults to 25 minutes', () {
    expect(SettingsNotifier().state.defaultFocusMinutes, 25);
  });

  test('saves and restores the default focus length', () async {
    SettingsNotifier().setDefaultFocusMinutes(45);
    await box.flush();

    expect(SettingsNotifier().state.defaultFocusMinutes, 45);
  });

  test('keeps a custom length within what the timer accepts', () {
    final settings = SettingsNotifier();

    settings.setDefaultFocusMinutes(0);
    expect(settings.state.defaultFocusMinutes, 1);

    settings.setDefaultFocusMinutes(500);
    expect(settings.state.defaultFocusMinutes, 180);
  });

  test('ignores a stored length that is out of range', () async {
    await box.put('defaultFocusMinutes', 0);
    expect(SettingsNotifier().state.defaultFocusMinutes, 25);

    await box.put('defaultFocusMinutes', 999);
    expect(SettingsNotifier().state.defaultFocusMinutes, 25);
  });

  test('reset restores the 25 minute default', () async {
    final settings = SettingsNotifier()..setDefaultFocusMinutes(45);

    settings.resetDefaults();
    // resetDefaults clears the box without awaiting it.
    await box.flush();

    expect(settings.state.defaultFocusMinutes, 25);
    expect(box.get('defaultFocusMinutes'), isNull);
  });

  test('reset leaves the saved focus session and the tab alone', () async {
    await box.put('focusSessionIsActive', true);
    final settings = SettingsNotifier()
      ..setLastTabIndex(1)
      ..setUserName('Saad');
    await box.flush();

    settings.resetDefaults();
    await box.flush();

    expect(settings.state.userName, '');
    expect(settings.state.lastTabIndex, 1);
    expect(box.get('userName'), isNull);
    expect(box.get('focusSessionIsActive'), isTrue);
  });
}
