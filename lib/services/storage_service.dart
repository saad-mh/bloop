import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/task.dart';
import '../utils/tag_utils.dart';

class StorageService {
  StorageService._();

  static const tasksBoxName = 'tasks';
  static const tagsBoxName = 'tags';
  static const settingsBoxName = 'settings';
  static const onboardingCompleteKey = 'onboardingComplete';
  static const onboardingExampleTaskKey = 'onboardingExampleTaskId';
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
  Box get _settingsBox => Hive.box(settingsBoxName);

  /// Whether first-run onboarding is done.
  ///
  /// With no flag stored, a box that already holds tasks, tags or settings
  /// belongs to someone who used the app before onboarding existed, so they
  /// are marked done instead of being walked through it.
  bool isOnboardingComplete() {
    final stored = _settingsBox.get(onboardingCompleteKey) as bool?;
    if (stored != null) return stored;
    final existingUser =
        _box.isNotEmpty || _tagsBox.isNotEmpty || _settingsBox.isNotEmpty;
    if (existingUser) markOnboardingComplete();
    return existingUser;
  }

  Future<void> markOnboardingComplete() =>
      _settingsBox.put(onboardingCompleteKey, true);

  /// Id of the example task onboarding left on Home, until it is completed or
  /// deleted.
  String? get onboardingExampleTaskId =>
      _settingsBox.get(onboardingExampleTaskKey) as String?;

  Future<void> setOnboardingExampleTaskId(String? id) => id == null
      ? _settingsBox.delete(onboardingExampleTaskKey)
      : _settingsBox.put(onboardingExampleTaskKey, id);

  Task? getById(String id) => _box.get(id);

  List<Task> getAll() =>
      _box.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

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
  /// The tag leaves the list last, so a failure partway leaves it listed and
  /// the delete can be retried.
  Future<void> deleteTag(String tag) async {
    for (final task in _box.values) {
      if (task.tags.contains(tag)) {
        task.tags.removeWhere((t) => t == tag);
        task.updatedAt = DateTime.now().toUtc();
        await task.save();
      }
    }
    await _tagsBox.delete(tag);
  }

  /// Renames [oldTag] on the tag list and on every task that carries it.
  /// Returns why [newTag] was refused, or null once renamed. The old name
  /// leaves the list last, so a failure partway leaves it listed and the
  /// rename can be retried.
  Future<TagNameError?> renameTag(String oldTag, String newTag) async {
    final error = validateTagName(newTag, getTags(), renaming: oldTag);
    if (error != null) return error;
    final name = newTag.trim();
    if (name == oldTag) return null;
    await _tagsBox.put(name, name);
    for (final task in _box.values) {
      if (!task.tags.contains(oldTag)) continue;
      // Swap the name in place and keep one copy, even if the task already
      // carried the new name or listed the old one twice.
      final renamed = <String>[];
      for (final t in task.tags) {
        final next = t == oldTag ? name : t;
        if (!renamed.contains(next)) renamed.add(next);
      }
      task.tags = renamed;
      task.updatedAt = DateTime.now().toUtc();
      await task.save();
    }
    await _tagsBox.delete(oldTag);
    return null;
  }
}
