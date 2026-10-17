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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(filteredActiveTasksProvider);
    final selectedTag = ref.watch(effectiveTagProvider);
    final userName = ref.watch(settingsProvider.select((s) => s.userName));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ScreenHeader(
              title: greetingFor(DateTime.now(), name: userName),
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
                    MaterialPageRoute(builder: (_) => const CompletedScreen()),
                  ),
                ),
                BloopIconButton(
                  icon: Icons.search,
                  tooltip: 'Search',
                  onPressed: () => _openSearch(context, ref),
                ),
              ],
            ),
            const _TagFilterRow(),
            Expanded(
              child: tasksAsync.when(
                data: (tasks) {
                  if (tasks.isEmpty) {
                    return Center(
                      child: Text(
                        selectedTag == null
                            ? 'No tasks yet \n Add some using the + button!'
                            : 'No tasks tagged "$selectedTag"',
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
      delegate: TaskSearchDelegate(
        tasks: [...active.requireValue, ...completed.requireValue],
        ref: ref,
      ),
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
  TaskSearchDelegate({required this.tasks, required this.ref});

  final List<Task> tasks;
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
    return _buildTaskList(context, _filterTasks(query));
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildTaskList(context, _filterTasks(query));
  }

  List<Task> _filterTasks(String q) {
    final normalized = q.trim().toLowerCase();
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

  Widget _buildTaskList(BuildContext context, List<Task> filtered) {
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
