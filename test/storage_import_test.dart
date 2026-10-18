import 'dart:typed_data';

import 'package:bloop/models/task.dart';
import 'package:bloop/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// The 1.x to 2.0 upgrade path: export, reinstall, import. Exports carry
/// tasks only, so the tag list has to be rebuilt from them.
void main() {
  final storage = StorageService.instance;

  setUpAll(() async {
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(PriorityAdapter());
    Hive.registerAdapter(RecurrenceAdapter());
    await Hive.openBox<Task>(StorageService.tasksBoxName, bytes: Uint8List(0));
    await Hive.openBox<String>(StorageService.tagsBoxName, bytes: Uint8List(0));
  });

  tearDownAll(() async {
    await Hive.close();
  });

  setUp(() async {
    await storage.clearAllTasks();
    await Hive.box<String>(StorageService.tagsBoxName).clear();
  });

  test('import returns the tasks and adds the tags they use', () async {
    await storage.upsert(Task(title: 'Lab record', tags: ['college', 'lab']));
    await storage.upsert(Task(title: 'Rent', tags: ['personal', 'college']));
    final json = storage.exportToJson();

    await storage.clearAllTasks();
    expect(storage.getTags(), isEmpty);

    final imported = await storage.importFromJson(json);

    expect(imported.map((t) => t.title), unorderedEquals(['Lab record', 'Rent']));
    expect(storage.getAll(), hasLength(2));
    expect(storage.getTags(), ['college', 'lab', 'personal']);
  });

  test('import keeps tags that already exist and does not duplicate them',
      () async {
    await storage.addTag('College');
    await storage.upsert(Task(title: 'Lab record', tags: ['college']));
    final json = storage.exportToJson();

    await storage.importFromJson(json);

    expect(storage.getTags(), ['College']);
  });
}
