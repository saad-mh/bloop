import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../utils/date_utils.dart';
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
    final dueDateTime = task.dueDateTime;
    final now = DateTime.now();
    final isOverdue = dueDateTime != null &&
        !task.isCompleted &&
        (task.allDay
            ? DateTime(
                dueDateTime.year,
                dueDateTime.month,
                dueDateTime.day,
                23,
                59,
                59,
              ).isBefore(now)
            : dueDateTime.isBefore(now));
    const overdueColor = Color(0xFFFF4D2D);
    final subtitle = dueDateTime != null
        ? formatDueDate(task.dueDateTime, allDay: task.allDay)
        : 'No date';

    final bgColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0E1B26)
        : Theme.of(context).cardColor;
    int alphaFromOpacity(double opacity) {
      final normalized = opacity.clamp(0.0, 1.0);
      return (normalized * 255).round();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context)
                  .dividerColor
                  .withAlpha(alphaFromOpacity(0.08)),
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => onToggleComplete?.call(!task.isCompleted),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: task.isCompleted
                        ? Theme.of(context).colorScheme.secondary
                        : Colors.transparent,
                    border: Border.all(
                      color: task.isCompleted
                          ? Colors.transparent
                          : Theme.of(context)
                              .dividerColor
                              .withAlpha(alphaFromOpacity(0.6)),
                      width: 2.2,
                    ),
                  ),
                  child: task.isCompleted
                      ? const Icon(Icons.check, size: 20, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      overflow: TextOverflow.ellipsis,
                      style: task.isCompleted
                          ? const TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            )
                          : TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.color,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (task.tags.isNotEmpty) TagChip(label: task.tags.first),
                        if (task.tags.isNotEmpty) const SizedBox(width: 12),
                        if (dueDateTime != null)
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_outlined,
                                size: 16,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withAlpha(alphaFromOpacity(0.7)),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  color: isOverdue
                                      ? overdueColor
                                      : Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withAlpha(alphaFromOpacity(0.8)),
                                  fontWeight:
                                      isOverdue ? FontWeight.w600 : null,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (task.notes != null && task.notes!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          task.notes!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withAlpha(alphaFromOpacity(0.8)),
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Theme.of(context)
                        .iconTheme
                        .color
                        ?.withAlpha(alphaFromOpacity(0.7)),
                  ),
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../utils/date_utils.dart';
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
    final dueDateTime = task.dueDateTime;
    final now = DateTime.now();
    final isOverdue =
        dueDateTime != null &&
        !task.isCompleted &&
        (task.allDay
            ? DateTime(
                dueDateTime.year,
                dueDateTime.month,
                dueDateTime.day,
                23,
                59,
                59,
              ).isBefore(now)
            : dueDateTime.isBefore(now));
    const overdueColor = Color(0xFFFF4D2D);
    final subtitle = dueDateTime != null
        ? formatDueDate(task.dueDateTime, allDay: task.allDay)
        : 'No date';
    // Card-like tile matching the provided mock
    final bgColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0E1B26)
        : Theme.of(context).cardColor;
    int alphaFromOpacity(double opacity) {
      final normalized = opacity.clamp(0.0, 1.0);
      return (normalized * 255).round();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(
                context,
              ).dividerColor.withAlpha(alphaFromOpacity(0.08)),
            ),
          ),
                        child: Text(
                          task.notes!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withAlpha(alphaFromOpacity(0.8)),
                            fontSize: 13,
                          ),
                        ),
                    border: Border.all(
                      color: task.isCompleted
                          ? Colors.transparent
                          : Theme.of(context)
                              .dividerColor
                              .withAlpha(alphaFromOpacity(0.6)),
                      width: 2.2,
                    ),
                  ),
                  child: task.isCompleted
                      ? const Icon(Icons.check, size: 20, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                              Text(
                                subtitle,
                                style: TextStyle(
                                  color: isOverdue
                                      ? overdueColor
                                      : Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withAlpha(alphaFromOpacity(0.8)),
                                  fontWeight: isOverdue ? FontWeight.w600 : null,
                                ),
                              ),
                              ).textTheme.titleLarge?.color,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                    ),
                    const SizedBox(height: 8),
                    // Tag(s) + time row
                    Row(
                      children: [
                        if (task.tags.isNotEmpty)
                          TagChip(label: task.tags.first),
                        if (task.tags.isNotEmpty) const SizedBox(width: 12),
                        if (dueDateTime != null)
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_outlined,
                                size: 16,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color
                                    ?.withAlpha(alphaFromOpacity(0.7)),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  color: isOverdue
                                      ? overdueColor
                                      : Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color
                                            ?.withAlpha(alphaFromOpacity(0.8)),
                                  fontWeight: isOverdue
                                      ? FontWeight.w600
                                      : null,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    // Notes
                    if (task.notes != null && task.notes!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          task.notes!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color
                                ?.withAlpha(alphaFromOpacity(0.8)),
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Muted delete icon (keeps original behavior)
              if (onDelete != null)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Theme.of(
                      context,
                    ).iconTheme.color?.withAlpha(alphaFromOpacity(0.7)),
                  ),
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
