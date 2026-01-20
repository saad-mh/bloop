import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/task_provider.dart';
import '../widgets/task_tile.dart';
import 'task_editor_screen.dart';

class CompletedScreen extends ConsumerWidget {
  const CompletedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(completedTasksProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Completed'),
        toolbarHeight: MediaQuery.of(context).size.height * 0.1,
        ),
      body: tasksAsync.when(
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(child: Text('Nothing completed yet'));
          }
          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
