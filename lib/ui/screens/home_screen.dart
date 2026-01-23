import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
            icon: const Icon(Icons.filter_list),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Add search functionality here
            },
          ),
        ],
      ),
      body: filteredTasksAsync.when(
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(child: Text('No tasks yet'));
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
        child: const Icon(Icons.add),
      ),
    );
  }
}
