import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task.dart';
import '../../providers/task_provider.dart';
import '../widgets/task_tile.dart';
import 'task_editor_screen.dart';

// Filter provider
final taskFilterProvider = StateProvider<String>((ref) => 'all');

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(activeTasksProvider);
    final selectedFilter = ref.watch(taskFilterProvider);
    final today = DateTime.now();
    final formattedDate = DateFormat('EEEE, MMM d').format(today);
    final filterLabels = <String, String>{
      'all': 'All Tasks',
      'today': 'Today',
      'overdue': 'Overdue',
      'upcoming': 'Upcoming',
    };

    // Filter tasks based on selected filter
    final filteredTasksAsync = tasksAsync.whenData((tasks) {
      switch (selectedFilter) {
        case 'overdue':
          return tasks.where((t) => t.dueDateTime != null && t.dueDateTime!.isBefore(today)).toList();
        case 'today':
          return tasks.where((t) {
            if (t.dueDateTime == null) return false;
            final dueDate = t.dueDateTime!;
            return dueDate.year == today.year &&
                dueDate.month == today.month &&
                dueDate.day == today.day;
          }).toList();
        case 'upcoming':
          return tasks.where((t) => t.dueDateTime != null && t.dueDateTime!.isAfter(today)).toList();
        case 'all':
        default:
          return tasks;
      }
    });

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: MediaQuery.of(context).size.height * 0.1,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Today'),
            Text(
              formattedDate,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              ref.read(taskFilterProvider.notifier).state = value;
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('All Tasks'),
              ),
              const PopupMenuItem(
                value: 'today',
                child: Text('Today'),
              ),
              const PopupMenuItem(
                value: 'overdue',
                child: Text('Overdue'),
              ),
              const PopupMenuItem(
                value: 'upcoming',
                child: Text('Upcoming'),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(filterLabels[selectedFilter] ?? 'All Tasks'),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final tasksValue = filteredTasksAsync;
              final selectedTask = await tasksValue.when(
                data: (tasks) => showSearch<Task?>(
                  context: context,
                  delegate: TaskSearchDelegate(
                    tasks: tasks,
                    ref: ref,
                  ),
                ),
                loading: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tasks are still loading.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return null;
                },
                error: (e, _) async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Search unavailable: $e'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return null;
                },
              );

              if (selectedTask != null && context.mounted) {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TaskEditorScreen(task: selectedTask),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: filteredTasksAsync.when(
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(child: Text('No tasks yet \n Add some using the + button!',
              textAlign: TextAlign.center,
            ));
          }
          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return TaskTile(
                key: ValueKey(task.id),
                task: task,
                animateOnComplete: true,
                onToggleComplete: (checked) async {
                  await ref.read(taskListProvider.notifier)
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
                  await ref.read(taskListProvider.notifier).delete(task);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TaskEditorScreen()),
          );
        },
        heroTag: 'home_fab',
        elevation: 2,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class TaskSearchDelegate extends SearchDelegate<Task?> {
  TaskSearchDelegate({
    required this.tasks,
    required this.ref,
  });

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
