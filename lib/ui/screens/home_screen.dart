import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/task.dart';
import '../../providers/collapsed_sections_provider.dart';
import '../../providers/day_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tab_provider.dart';
import '../../providers/tags_provider.dart';
import '../../providers/task_provider.dart';
import '../../utils/greeting.dart';
import '../../utils/task_reschedule.dart';
import '../../utils/task_sections.dart';
import '../theme/tokens.dart';
import '../widgets/bloop_icon_button.dart';
import '../widgets/choice_chip.dart';
import '../widgets/floating_nav.dart';
import '../widgets/screen_header.dart';
import '../widgets/section_header.dart';
import '../widgets/task_action_bar.dart';
import '../widgets/task_tile.dart';
import 'completed_screen.dart';
import 'focus_controller.dart';
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

    // A task added without a date would otherwise vanish into the collapsed
    // Whenever section.
    ref.listen(taskListProvider, (prev, next) {
      final before = prev?.valueOrNull;
      final after = next.valueOrNull;
      if (before == null || after == null) return;
      if (addedUndatedTask(before, after)) {
        ref
            .read(collapsedSectionsProvider.notifier)
            .update((c) => {...c}..remove(TaskSection.whenever));
      }
    });

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
                  icon: LucideIcons.settings,
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
                            : 'No tasks yet\nTap + to add your first one.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return _SectionedTaskList(tasks: tasks);
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

/// Active tasks under collapsible Overdue / Today / Upcoming / Whenever
/// headers. Empty sections are left out.
///
/// Tapping a row opens it in place; only one row is open at a time.
class _SectionedTaskList extends ConsumerStatefulWidget {
  const _SectionedTaskList({required this.tasks});

  final List<Task> tasks;

  @override
  ConsumerState<_SectionedTaskList> createState() => _SectionedTaskListState();
}

class _SectionedTaskListState extends ConsumerState<_SectionedTaskList> {
  /// Id of the open row, if any.
  String? _expandedId;

  void _toggleExpanded(Task task) =>
      setState(() => _expandedId = _expandedId == task.id ? null : task.id);

  void _collapse() {
    if (_expandedId != null) setState(() => _expandedId = null);
  }

  Future<void> _complete(Task task, bool? checked) async {
    _collapse();
    await ref
        .read(taskListProvider.notifier)
        .toggleComplete(task, value: checked);
  }

  Future<void> _delete(Task task) async {
    _collapse();
    await ref.read(taskListProvider.notifier).delete(task);
  }

  Future<void> _edit(Task task) async {
    _collapse();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => TaskEditorScreen(task: task)));
  }

  Future<void> _snooze(Task task) async {
    _collapse();
    await ref
        .read(taskListProvider.notifier)
        .addOrUpdate(snoozed(task, DateTime.now()));
  }

  Future<void> _moveToTomorrow(Task task) async {
    _collapse();
    await ref
        .read(taskListProvider.notifier)
        .addOrUpdate(movedToTomorrow(task, DateTime.now()));
  }

  /// Starts a focus session on [task] and shows the Focus tab. A session in
  /// progress, running or paused, is only replaced once the user agrees.
  Future<void> _focus(Task task) async {
    final focus = ref.read(focusControllerProvider);
    if (focus.isSessionActive) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace current session?'),
          content: Text(
            'Starting a focus session for "${task.title}" ends the one in '
            'progress.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep current'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    _collapse();
    focus.startForTask(task);
    ref.read(selectedTabProvider.notifier).select(focusTabIndex);
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = ref.watch(collapsedSectionsProvider);
    final now = ref.watch(dayProvider);

    final rows = <Object>[];
    for (final group in groupTasksBySection(widget.tasks, now)) {
      rows.add(group);
      if (!collapsed.contains(group.section)) rows.addAll(group.tasks);
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: floatingNavClearance(context)),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row is TaskGroup) {
          final section = row.section;
          return SectionHeader(
            key: ValueKey('section-${section.name}'),
            label: section.label,
            count: row.tasks.length,
            date: section == TaskSection.today
                ? DateFormat.MMMEd().format(now)
                : null,
            expanded: !collapsed.contains(section),
            onToggle: () => ref
                .read(collapsedSectionsProvider.notifier)
                .update(
                  (current) => current.contains(section)
                      ? ({...current}..remove(section))
                      : {...current, section},
                ),
          );
        }
        final task = row as Task;
        return TaskTile(
          key: ValueKey(task.id),
          task: task,
          animateOnComplete: true,
          expanded: _expandedId == task.id,
          actions: _RowActions(
            onFocus: () => _focus(task),
            onSnooze: () => _snooze(task),
            onTomorrow: () => _moveToTomorrow(task),
            onEdit: () => _edit(task),
          ),
          onToggleComplete: (checked) => _complete(task, checked),
          onTap: () => _toggleExpanded(task),
          onDelete: () => _delete(task),
        );
      },
    );
  }
}

/// [TaskActionBar] with the focus length read from the session settings. A
/// widget of its own so the home list only listens to the focus controller
/// while a row is open.
class _RowActions extends ConsumerWidget {
  const _RowActions({
    required this.onFocus,
    required this.onSnooze,
    required this.onTomorrow,
    required this.onEdit,
  });

  final VoidCallback onFocus;
  final VoidCallback onSnooze;
  final VoidCallback onTomorrow;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minutes = ref.watch(
      focusControllerProvider.select((c) => c.focusDuration.inMinutes),
    );
    return TaskActionBar(
      focusMinutes: minutes,
      onFocus: onFocus,
      onSnooze: onSnooze,
      onTomorrow: onTomorrow,
      onEdit: onEdit,
    );
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
