import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../utils/date_utils.dart';
import 'priority_indicator.dart';
import 'tag_chip.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    this.onToggleComplete,
    this.onTap,
    this.onDelete,
  });

  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final ValueChanged<bool?>? onToggleComplete;

  @override
  Widget build(BuildContext context) {
    final subtitle = task.dueDateTime != null
        ? formatDueDate(task.dueDateTime, allDay: task.allDay)
        : 'No date';
    return ListTile(
      leading: Checkbox(
        value: task.isCompleted,
        onChanged: onToggleComplete,
      ),
      title: Row(
        children: [
          PriorityIndicator(priority: task.priority),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              task.title,
              overflow: TextOverflow.ellipsis,
              style: task.isCompleted
                  ? const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey,
                    )
                  : null,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          if (task.tags.isNotEmpty)
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: task.tags.map((t) => TagChip(label: t)).toList(),
            ),
          if (task.notes != null && task.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                task.notes!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
      onTap: onTap,
    );
  }
}
