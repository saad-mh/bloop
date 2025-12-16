import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/task.dart';

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

  Future<void> addTag(String tag) async {
    if (tag.trim().isEmpty) return;
    await _tagsBox.put(tag, tag);
  }

  Future<void> deleteTag(String tag) async {
    await _tagsBox.delete(tag);
    // Remove tag from all tasks
    for (final task in _box.values) {
      if (task.tags.contains(tag)) {
        task.tags.remove(tag);
        task.updatedAt = DateTime.now().toUtc();
        await task.save();
      }
    }
  }

  Future<void> renameTag(String oldTag, String newTag) async {
    if (newTag.trim().isEmpty) return;
    if (oldTag == newTag) return;
    await _tagsBox.delete(oldTag);
    await _tagsBox.put(newTag, newTag);
    for (final task in _box.values) {
      final idx = task.tags.indexOf(oldTag);
      if (idx != -1) {
        task.tags[idx] = newTag;
        task.updatedAt = DateTime.now().toUtc();
        await task.save();
      }
    }
  }
}
