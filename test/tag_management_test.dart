import 'dart:io';

import 'package:bloop/models/recurrence.dart';
import 'package:bloop/models/task.dart';
import 'package:bloop/providers/tags_provider.dart';
import 'package:bloop/providers/task_provider.dart';
import 'package:bloop/services/storage_service.dart';
import 'package:bloop/utils/tag_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Serves a fixed list instead of reading Hive and the notification plugin.
class _FixedTasks extends TaskNotifier {
  _FixedTasks(List<Task> tasks) {
    state = AsyncData(tasks);
  }

  @override
  Future<void> load() async {}
}

Task _task(String title, List<String> tags, {bool done = false}) =>
    Task(title: title, tags: tags, isCompleted: done);

void main() {
  group('validateTagName', () {
    test('rejects empty and whitespace-only names', () {
      expect(validateTagName('', const []), TagNameError.empty);
      expect(validateTagName('   ', const ['a']), TagNameError.empty);
    });

    test('rejects duplicates regardless of case or padding', () {
      expect(validateTagName('work', ['work']), TagNameError.duplicate);
      expect(validateTagName('  WORK ', ['work']), TagNameError.duplicate);
      expect(validateTagName('Work', ['home', 'work']), TagNameError.duplicate);
    });

    test('accepts a new name', () {
      expect(validateTagName('home', ['work']), isNull);
    });

    test('lets a tag keep its own name or change case when renamed', () {
      expect(validateTagName('work', ['work'], renaming: 'work'), isNull);
      expect(validateTagName('Work', ['work'], renaming: 'work'), isNull);
    });

    test('still rejects another tag\'s name when renaming', () {
      expect(
        validateTagName('HOME', ['work', 'home'], renaming: 'work'),
        TagNameError.duplicate,
      );
    });
  });

  group('openTaskCounts', () {
    test('counts open tasks per tag and ignores completed ones', () {
      final counts = openTaskCounts([
        _task('a', ['college', 'robotics']),
        _task('b', ['college']),
        _task('c', ['college'], done: true),
        _task('d', ['personal'], done: true),
        _task('e', []),
      ]);
      expect(counts, {'college': 2, 'robotics': 1});
    });

    test('counts a task once even if it lists a tag twice', () {
      expect(openTaskCounts([_task('a', ['x', 'x'])]), {'x': 1});
    });
  });

  group('taskCountForTag', () {
    test('includes completed tasks, since delete touches them too', () {
      final tasks = [
        _task('a', ['x']),
        _task('b', ['x'], done: true),
        _task('c', ['y']),
      ];
      expect(taskCountForTag(tasks, 'x'), 2);
      expect(taskCountForTag(tasks, 'z'), 0);
    });
  });

  test('tagOpenCountsProvider follows the task list', () {
    final container = ProviderContainer(
      overrides: [
        taskListProvider.overrideWith(
          (ref) => _FixedTasks([
            _task('a', ['x']),
            _task('b', ['x'], done: true),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(tagOpenCountsProvider), {'x': 1});
  });

  group('StorageService tags', () {
    late Directory dir;
    final storage = StorageService.instance;

    setUpAll(() async {
      dir = await Directory.systemTemp.createTemp('bloop_tags_test');
      Hive.init(dir.path);
      Hive.registerAdapter(TaskAdapter());
      Hive.registerAdapter(PriorityAdapter());
      Hive.registerAdapter(RecurrenceAdapter());
      await Hive.openBox<Task>(StorageService.tasksBoxName);
      await Hive.openBox<String>(StorageService.tagsBoxName);
    });

    tearDownAll(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    setUp(() async {
      await Hive.box<Task>(StorageService.tasksBoxName).clear();
      await Hive.box<String>(StorageService.tagsBoxName).clear();
    });

    Future<Task> put(String title, List<String> tags, {bool done = false}) async {
      final task = _task(title, tags, done: done);
      await storage.upsert(task);
      return storage.getById(task.id)!;
    }

    test('addTag stores the trimmed name', () async {
      expect(await storage.addTag('  college '), isNull);
      expect(storage.getTags(), ['college']);
    });

    test('addTag refuses empty and case-insensitive duplicates', () async {
      await storage.addTag('college');
      expect(await storage.addTag('  '), TagNameError.empty);
      expect(await storage.addTag('College'), TagNameError.duplicate);
      expect(storage.getTags(), ['college']);
    });

    test('renameTag updates the tag list and every task, done or not', () async {
      await storage.addTag('college');
      final open = await put('a', ['college', 'robotics']);
      final done = await put('b', ['college'], done: true);
      final other = await put('c', ['robotics']);

      expect(await storage.renameTag('college', 'uni'), isNull);

      expect(storage.getTags(), ['uni']);
      expect(storage.getById(open.id)!.tags, ['uni', 'robotics']);
      expect(storage.getById(done.id)!.tags, ['uni']);
      expect(storage.getById(other.id)!.tags, ['robotics']);
    });

    test('renameTag allows a change of case on the same tag', () async {
      await storage.addTag('work');
      final task = await put('a', ['work']);

      expect(await storage.renameTag('work', 'Work'), isNull);

      expect(storage.getTags(), ['Work']);
      expect(storage.getById(task.id)!.tags, ['Work']);
    });

    test('renameTag refuses empty and duplicate names and changes nothing',
        () async {
      await storage.addTag('college');
      await storage.addTag('robotics');
      final task = await put('a', ['college']);

      expect(await storage.renameTag('college', ' '), TagNameError.empty);
      expect(
        await storage.renameTag('college', 'ROBOTICS'),
        TagNameError.duplicate,
      );

      expect(storage.getTags(), ['college', 'robotics']);
      expect(storage.getById(task.id)!.tags, ['college']);
    });

    test('renameTag keeps one copy when a task already has the new name',
        () async {
      await storage.addTag('college');
      final task = await put('a', ['college', 'uni']);

      await storage.renameTag('college', 'uni');

      expect(storage.getById(task.id)!.tags, ['uni']);
    });

    test('deleteTag removes the tag from every task and keeps the tasks',
        () async {
      await storage.addTag('college');
      await storage.addTag('robotics');
      final open = await put('a', ['college', 'robotics']);
      final done = await put('b', ['college'], done: true);
      final other = await put('c', ['robotics']);

      await storage.deleteTag('college');

      expect(storage.getTags(), ['robotics']);
      expect(storage.getById(open.id)!.tags, ['robotics']);
      expect(storage.getById(done.id)!.tags, isEmpty);
      expect(storage.getById(other.id)!.tags, ['robotics']);
      expect(storage.getAll(), hasLength(3));
    });
  });
}
