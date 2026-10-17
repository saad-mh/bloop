import 'dart:io';

import 'package:bloop/main.dart';
import 'package:bloop/models/task.dart';
import 'package:bloop/services/storage_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory dir;

  setUpAll(() async {
    // StorageService.init() calls Hive.initFlutter, which needs a platform
    // path, so set up the same adapters and boxes against a temp directory.
    dir = await Directory.systemTemp.createTemp('bloop_test');
    Hive.init(dir.path);
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(PriorityAdapter());
    Hive.registerAdapter(RecurrenceAdapter());
    await Hive.openBox<Task>(StorageService.tasksBoxName);
    await Hive.openBox<String>(StorageService.tagsBoxName);
    await Hive.openBox(StorageService.settingsBoxName);
  });

  testWidgets('Smoke test builds app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BloopApp()));
    await tester.pumpAndSettle();

    expect(find.text('Tasks'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
