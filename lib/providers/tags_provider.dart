import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../services/storage_service.dart';
import '../utils/tag_utils.dart';
import 'task_provider.dart';

final tagsProvider =
    StateNotifierProvider<TagsNotifier, AsyncValue<List<String>>>((ref) {
  return TagsNotifier(
    StorageService.instance,
    onTasksChanged: () => ref.read(taskListProvider.notifier).load(),
    onRenamed: (oldTag, newTag) {
      // Keep the home filter on the tag instead of dropping back to All.
      if (ref.read(selectedTagProvider) == oldTag) {
        ref.read(selectedTagProvider.notifier).state = newTag;
      }
    },
  )..load();
});

/// Open (not completed) task count per tag name; tags with none are absent.
final tagOpenCountsProvider = Provider<Map<String, int>>((ref) {
  final tasks = ref.watch(taskListProvider).valueOrNull ?? const <Task>[];
  return openTaskCounts(tasks);
});

class TagsNotifier extends StateNotifier<AsyncValue<List<String>>> {
  TagsNotifier(this._storage, {this.onTasksChanged, this.onRenamed})
      : super(const AsyncValue.loading());

  final StorageService _storage;

  /// Called after a rename or delete rewrote tasks, so task lists reload.
  final Future<void> Function()? onTasksChanged;

  final void Function(String oldTag, String newTag)? onRenamed;

  Future<void> load() async {
    try {
      final tags = _storage.getTags();
      state = AsyncValue.data(tags);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Returns why [tag] was refused, or null once added.
  Future<TagNameError?> addTag(String tag) async {
    try {
      final error = await _storage.addTag(tag);
      await load();
      return error;
    } catch (_) {
      return TagNameError.failed;
    }
  }

  Future<void> deleteTag(String tag) async {
    try {
      await _storage.deleteTag(tag);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
    await load();
    await onTasksChanged?.call();
  }

  /// Returns why [newTag] was refused, or null once renamed.
  Future<TagNameError?> renameTag(String oldTag, String newTag) async {
    TagNameError? error;
    try {
      error = await _storage.renameTag(oldTag, newTag);
    } catch (_) {
      error = TagNameError.failed;
    }
    if (error == TagNameError.failed) {
      // Some tasks may already carry the new name.
      await load();
      await onTasksChanged?.call();
      return error;
    }
    if (error != null) return error;
    onRenamed?.call(oldTag, newTag.trim());
    await load();
    await onTasksChanged?.call();
    return null;
  }
}
