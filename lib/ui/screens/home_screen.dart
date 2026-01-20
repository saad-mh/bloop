import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/task_provider.dart';
import '../widgets/task_tile.dart';
import 'task_editor_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(activeTasksProvider);
    final today = DateTime.now();
    final formattedDate = DateFormat('EEEE, MMM d').format(today);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
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
      ),
      body: tasksAsync.when(
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
