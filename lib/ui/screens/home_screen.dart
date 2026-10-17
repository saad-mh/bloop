import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tags_provider.dart';
import '../../providers/task_provider.dart';
import '../../utils/greeting.dart';
import '../theme/tokens.dart';
import '../widgets/bloop_icon_button.dart';
import '../widgets/choice_chip.dart';
import '../widgets/floating_nav.dart';
import '../widgets/screen_header.dart';
import '../widgets/task_tile.dart';
import 'completed_screen.dart';
import 'settings_screen.dart';
import 'task_editor_screen.dart';

/// Width ScreenHeader gives to everything but the title: its horizontal
/// padding, the gear, the gap after it, and the two action buttons.
const double _headerButtonsWidth =
    2 * BloopSpace.x2 + 3 * kBloopMinTouchTarget + BloopSpace.x1;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// The greeting, or plain "Tasks" when it wouldn't fit in [available]
  /// (narrow phone, long name or large text size) and would be cut off.
  String _headerTitle(BuildContext context, String userName, double available) {
    final greeting = greetingFor(DateTime.now(), name: userName);
    final painter = TextPainter(
      text: TextSpan(
        text: greeting,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final fits = painter.width <= available;
    painter.dispose();
    return fits ? greeting : 'Tasks';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(filteredActiveTasksProvider);
    final selectedTag = ref.watch(effectiveTagProvider);
    final userName = ref.watch(settingsProvider.select((s) => s.userName));

    // Tasks-only means nothing left to do, as opposed to nothing added yet.
    final hasCompleted =
        ref.watch(completedTasksProvider).valueOrNull?.isNotEmpty ?? false;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) => ScreenHeader(
                title: _headerTitle(
                  context,
                  userName,
                  constraints.maxWidth - _headerButtonsWidth,
                ),
                leading: BloopIconButton(
                  icon: Icons.settings_outlined,
                  tooltip: 'Settings',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
                actions: [
                  // TODO(#13): remove once Completed is a section of this list.
                  BloopIconButton(
                    icon: Icons.done_all,
                    tooltip: 'Completed',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CompletedScreen(),
                      ),
                    ),
                  ),
                  BloopIconButton(
                    icon: Icons.search,
                    tooltip: 'Search',
                    onPressed: () => _openSearch(context, ref),
                  ),
                ],
              ),
            ),
            const _TagFilterRow(),
            Expanded(
              child: tasksAsync.when(
                data: (tasks) {
                  if (tasks.isEmpty) {
                    return Center(
                      child: Text(
                        selectedTag != null
                            ? 'No tasks tagged "$selectedTag"'
                            : hasCompleted
                            ? "You're all done!"
                            : 'No tasks yet \n Add some using the + button!',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: EdgeInsets.only(
                      bottom: floatingNavClearance(context),
                    ),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return TaskTile(
                        key: ValueKey(task.id),
                        task: task,
                        animateOnComplete: true,
                        onToggleComplete: (checked) async {
                          await ref
                              .read(taskListProvider.notifier)
                              .toggleComplete(task, value: checked);
                        },
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TaskEditorScreen(task: task),
                            ),
                          );
                        },
                        onDelete: () async {
                          await ref
                              .read(taskListProvider.notifier)
                              .delete(task);
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Search covers every active task, whatever tag chip is selected, and the
  /// completed ones after them.
  Future<void> _openSearch(BuildContext context, WidgetRef ref) async {
    final active = ref.read(activeTasksProvider);
    final completed = ref.read(completedTasksProvider);
    final messenger = ScaffoldMessenger.of(context);

    void notify(String message) {
      messenger.showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }

    final error = active.error ?? completed.error;
    if (error != null) {
      notify('Search unavailable: $error');
      return;
    }
    if (!active.hasValue || !completed.hasValue) {
      notify('Tasks are still loading.');
      return;
    }

    final selectedTask = await showSearch<Task?>(
      context: context,
      delegate: TaskSearchDelegate(ref: ref),
    );

    if (selectedTask != null && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TaskEditorScreen(task: selectedTask)),
      );
    }
  }
}

/// Horizontally scrolling "All" + one chip per tag. Selecting a tag filters
/// the whole home list; selecting it again, or All, clears the filter.
class _TagFilterRow extends ConsumerWidget {
  const _TagFilterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagsProvider).valueOrNull ?? const <String>[];
    final selected = ref.watch(effectiveTagProvider);
    final notifier = ref.read(selectedTagProvider.notifier);

    // Drop the stored choice once its tag is renamed or deleted, so creating
    // a tag with the old name later doesn't silently re-apply the filter.
    ref.listen(tagsProvider, (_, next) {
      final tags = next.valueOrNull;
      final chosen = ref.read(selectedTagProvider);
      if (tags != null && chosen != null && !tags.contains(chosen)) {
        notifier.state = null;
      }
    });

    return SizedBox(
      height: kBloopMinTouchTarget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: BloopSpace.x4),
        itemCount: tags.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: BloopSpace.x2),
        itemBuilder: (context, index) {
          if (index == 0) {
            return BloopChoiceChip(
              label: 'All',
              selected: selected == null,
              onSelected: (_) => notifier.state = null,
            );
          }
          final tag = tags[index - 1];
          return BloopChoiceChip(
            key: ValueKey('tag-chip-$tag'),
            label: tag,
            selected: selected == tag,
            onSelected: (on) => notifier.state = on ? tag : null,
          );
        },
      ),
    );
  }
}

class TaskSearchDelegate extends SearchDelegate<Task?> {
  TaskSearchDelegate({required this.ref});

  final WidgetRef ref;

  @override
  String get searchFieldLabel => 'Search through tasks';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildTaskList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildTaskList(context);
  }

  /// Every active task, then the completed ones, read live so ticking or
  /// deleting a result updates the list.
  Widget _buildTaskList(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final active = ref.watch(activeTasksProvider).valueOrNull ?? const [];
        final completed =
            ref.watch(completedTasksProvider).valueOrNull ?? const [];
        return _buildResults(context, _filterTasks([...active, ...completed]));
      },
    );
  }

  List<Task> _filterTasks(List<Task> tasks) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return tasks;
    return tasks.where((task) {
      final title = task.title.toLowerCase();
      final notes = (task.notes ?? '').toLowerCase();
      final tags = task.tags.join(' ').toLowerCase();
      return title.contains(normalized) ||
          notes.contains(normalized) ||
          tags.contains(normalized);
    }).toList();
  }

  Widget _buildResults(BuildContext context, List<Task> filtered) {
    if (filtered.isEmpty) {
      return const Center(child: Text('[?] No such task found'));
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final task = filtered[index];
        return TaskTile(
          key: ValueKey(task.id),
          task: task,
          animateOnComplete: true,
          onToggleComplete: (checked) async {
            await ref
                .read(taskListProvider.notifier)
                .toggleComplete(task, value: checked);
          },
          onTap: () => close(context, task),
          onDelete: () async {
            await ref.read(taskListProvider.notifier).delete(task);
          },
        );
      },
    );
  }
}
