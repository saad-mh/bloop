import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';

final tagsProvider =
    StateNotifierProvider<TagsNotifier, AsyncValue<List<String>>>((ref) {
  return TagsNotifier(StorageService.instance)..load();
});

class TagsNotifier extends StateNotifier<AsyncValue<List<String>>> {
  TagsNotifier(this._storage) : super(const AsyncValue.loading());

  final StorageService _storage;

  Future<void> load() async {
    try {
      final tags = _storage.getTags();
      state = AsyncValue.data(tags);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addTag(String tag) async {
    try {
      await _storage.addTag(tag);
      await load();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteTag(String tag) async {
    try {
      await _storage.deleteTag(tag);
      await load();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> renameTag(String oldTag, String newTag) async {
    try {
      await _storage.renameTag(oldTag, newTag);
      await load();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
