import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';
import '../utils/onboarding_content.dart';
import '../utils/tag_utils.dart';
import 'settings_provider.dart';
import 'tags_provider.dart';
import 'task_provider.dart';

/// True once first-run onboarding is done. `main.dart` shows onboarding until
/// then and the normal shell after.
final onboardingProvider = StateNotifierProvider<OnboardingNotifier, bool>((
  ref,
) {
  return OnboardingNotifier(ref);
});

/// Id of the example task onboarding left on Home; null once it has been
/// completed or deleted. Completing it fires the confetti.
final exampleTaskIdProvider = StateProvider<String?>((ref) {
  try {
    return StorageService.instance.onboardingExampleTaskId;
  } catch (_) {
    return null;
  }
});

class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier(this._ref, {StorageService? storage})
    : _storage = storage ?? StorageService.instance,
      super(_read(storage ?? StorageService.instance));

  final Ref _ref;
  final StorageService _storage;

  /// A box that can't be read must not trap the user in onboarding.
  static bool _read(StorageService storage) {
    try {
      return storage.isOnboardingComplete();
    } catch (_) {
      return true;
    }
  }

  /// Forgets the example task once it has been completed or deleted, so the
  /// confetti can't fire for it again.
  Future<void> clearExampleTask() async {
    _ref.read(exampleTaskIdProvider.notifier).state = null;
    try {
      await _storage.setOnboardingExampleTaskId(null);
    } catch (_) {}
  }

  /// Saves the [name] and [tags] the user chose, adds the example task and
  /// moves on to Home. Returns false, staying in onboarding, when something
  /// could not be saved; it is safe to try again.
  Future<bool> finish({String name = '', List<String> tags = const []}) async {
    try {
      final created = <String>[];
      for (final tag in tags) {
        final error = await _ref.read(tagsProvider.notifier).addTag(tag);
        // Already there from an earlier try, or made in Settings meanwhile.
        if (error != null && error != TagNameError.duplicate) return false;
        created.add(tag.trim());
      }

      if (name.trim().isNotEmpty) {
        _ref.read(settingsProvider.notifier).setUserName(name);
      }

      // An earlier try that got this far already left the example behind;
      // adding another would orphan it, with no confetti when completed.
      final leftBehind = _storage.onboardingExampleTaskId;
      if (leftBehind == null || _storage.getById(leftBehind) == null) {
        final example = buildExampleTask(
          DateTime.now(),
          tag: created.isEmpty ? null : created.first,
        );
        // The id is stored first, so a failure after the task is saved still
        // leaves it known. Saved directly rather than through the task list's
        // addOrUpdate: that schedules reminders, which asks Android for
        // notification permission, and the example has none. The permission
        // prompt is not part of onboarding.
        await _storage.setOnboardingExampleTaskId(example.id);
        await _storage.upsert(example);
        _ref.read(exampleTaskIdProvider.notifier).state = example.id;
      } else {
        _ref.read(exampleTaskIdProvider.notifier).state = leftBehind;
      }
      await _ref.read(taskListProvider.notifier).load();

      await _storage.markOnboardingComplete();
      state = true;
      return true;
    } catch (e, st) {
      debugPrint('Onboarding finish failed: $e\n$st');
      return false;
    }
  }
}
