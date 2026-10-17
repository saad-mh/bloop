import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/task.dart';
import '../utils/tag_utils.dart';

class StorageService {
  StorageService._();

  static const tasksBoxName = 'tasks';
  static const tagsBoxName = 'tags';
  static const settingsBoxName = 'settings';
  static final StorageService instance = StorageService._();

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(PriorityAdapter());
    Hive.registerAdapter(RecurrenceAdapter());
    await Hive.openBox<Task>(tasksBoxName);
    await Hive.openBox<String>(tagsBoxName);
    await Hive.openBox(settingsBoxName);
  }

  Box<Task> get _box => Hive.box<Task>(tasksBoxName);
  Box<String> get _tagsBox => Hive.box<String>(tagsBoxName);

  Task? getById(String id) => _box.get(id);

  List<Task> getAll() => _box.values.toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Future<void> upsert(Task task) async {
    task.updatedAt = DateTime.now().toUtc();
    await _box.put(task.id, task);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> clearAllTasks() async {
    await _box.clear();
  }

  Future<void> toggleComplete(String id, {bool? value}) async {
    final task = _box.get(id);
    if (task == null) return;
    final now = DateTime.now().toUtc();
    task
      ..isCompleted = value ?? !task.isCompleted
      ..completedAt = (value ?? !task.isCompleted) ? now : null
      ..updatedAt = now;
    await task.save();
  }

  String exportToJson() {
    final data = _box.values.map((t) => t.toJson()).toList();
    return jsonEncode(data);
  }

  Future<void> importFromJson(String json) async {
    final decoded = jsonDecode(json) as List<dynamic>;
    for (final item in decoded) {
      final task = Task.fromJson(item as Map<String, dynamic>);
      await _box.put(task.id, task);
    }
  }

  List<String> getTags() => _tagsBox.values.toList()..sort();

  /// Stores [tag] trimmed. Returns why it was refused, or null once stored.
  Future<TagNameError?> addTag(String tag) async {
    final error = validateTagName(tag, getTags());
    if (error != null) return error;
    final name = tag.trim();
    await _tagsBox.put(name, name);
    return null;
  }

  /// Removes [tag] and strips it from every task, completed ones included.
  Future<void> deleteTag(String tag) async {
    await _tagsBox.delete(tag);
    for (final task in _box.values) {
      if (task.tags.contains(tag)) {
        task.tags.removeWhere((t) => t == tag);
        task.updatedAt = DateTime.now().toUtc();
        await task.save();
      }
    }
  }

  /// Renames [oldTag] on the tag list and on every task that carries it.
  /// Returns why [newTag] was refused, or null once renamed.
  Future<TagNameError?> renameTag(String oldTag, String newTag) async {
    final error = validateTagName(newTag, getTags(), renaming: oldTag);
    if (error != null) return error;
    final name = newTag.trim();
    if (name == oldTag) return null;
    await _tagsBox.delete(oldTag);
    await _tagsBox.put(name, name);
    for (final task in _box.values) {
      if (!task.tags.contains(oldTag)) continue;
      // A task may already carry the new name from before the tag list
      // tracked it; keep one copy.
      final alreadyHasNew = task.tags.contains(name);
      task.tags = [
        for (final t in task.tags)
          if (t != oldTag)
            t
          else if (!alreadyHasNew)
            name,
      ];
      task.updatedAt = DateTime.now().toUtc();
      await task.save();
    }
    return null;
  }
}
