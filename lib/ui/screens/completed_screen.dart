import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task.dart';
import '../../providers/settings_provider.dart';
import '../../providers/task_provider.dart';
import '../widgets/task_tile.dart';
import 'task_editor_screen.dart';

class CompletedScreen extends ConsumerStatefulWidget {
  const CompletedScreen({super.key});

  @override
  ConsumerState<CompletedScreen> createState() => _CompletedScreenState();
}

class _CompletedScreenState extends ConsumerState<CompletedScreen> {
  late final ConfettiController _confettiController;
  bool _isActive = false;
  bool _playedForActiveSession = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _playConfetti() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _confettiController.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(completedTasksProvider);
    final allTasksAsync = ref.watch(taskListProvider);
    final allTasks = allTasksAsync.asData?.value ?? const [];
    final today = DateTime.now();
    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    final todayTasks = allTasks
        .where(
          (t) =>
              t.dueDateTime != null &&
              isSameDay(t.dueDateTime!.toLocal(), today),
        )
        .toList();
    final completedToday = todayTasks.where((t) => t.isCompleted).length;
    final allTodayComplete =
        todayTasks.isNotEmpty && completedToday == todayTasks.length;
    final showTodaySummary = todayTasks.isNotEmpty && completedToday > 0;
    final settings = ref.watch(settingsProvider);
    final isActive = settings.lastTabIndex == 1;
    final textToShow = allTasks.isEmpty ? "You dont even have any tasks" : "No tasks completed yet";
    if (isActive != _isActive) {
      _isActive = isActive;
      if (_isActive) {
        _playedForActiveSession = false;
      }
    }
    if (_isActive && allTodayComplete && !_playedForActiveSession) {
      _playedForActiveSession = true;
      _playConfetti();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Completed'),
        toolbarHeight: MediaQuery.of(context).size.height * 0.1,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final selectedTask = await tasksAsync.when(
                data: (tasks) => showSearch<Task?>(
                  context: context,
                  delegate: CompletedTaskSearchDelegate(
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

              if (selectedTask != null && mounted) {
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
      body: Stack(
        children: [
          tasksAsync.when(
            data: (tasks) {
              if (tasks.isEmpty) {
                return Center(child: Text(textToShow));
              }
              return ListView.builder(
                itemCount: tasks.length + (showTodaySummary ? 1 : 0),
                itemBuilder: (context, index) {
                  if (showTodaySummary && index == 0) {
                    final progress = todayTasks.isEmpty
                        ? 0.0
                        : completedToday / todayTasks.length;
                    return Card(
                      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              allTodayComplete
                                  ? 'Good Job'
                                  : "Today's progress",
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              allTodayComplete
                                  ? "on completing all of today's tasks"
                                  : '$completedToday of ${todayTasks.length} tasks completed',
                            ),
                            const SizedBox(height: 10),
                            LinearProgressIndicator(
                              value: progress,
                              year2023: false,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final taskIndex = showTodaySummary ? index - 1 : index;
                  final task = tasks[taskIndex];
                  return TaskTile(
                    key: ValueKey(task.id),
                    task: task,
                    animateOnUncomplete: true,
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
                      await ref.read(taskListProvider.notifier).delete(task);
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(year2023: false,)),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          Align(
            alignment: Alignment.center,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.03,
              numberOfParticles: 24,
              gravity: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class CompletedTaskSearchDelegate extends SearchDelegate<Task?> {
  CompletedTaskSearchDelegate({
    required this.tasks,
    required this.ref,
  });

  final List<Task> tasks;
  final WidgetRef ref;

  @override
  String get searchFieldLabel => 'Search completed tasks';

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
      return const Center(child: Text('No matching tasks'));
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final task = filtered[index];
        return TaskTile(
          key: ValueKey(task.id),
          task: task,
          animateOnUncomplete: true,
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
