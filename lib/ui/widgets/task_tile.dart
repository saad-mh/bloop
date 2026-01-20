import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/task.dart';
import '../../utils/date_utils.dart';
import 'tag_chip.dart';

class TaskTile extends StatefulWidget {
  const TaskTile({
    super.key,
    required this.task,
    this.onToggleComplete,
    this.onTap,
    this.onDelete,
    this.animateOnComplete = false,
    this.animateOnUncomplete = false,
  });

  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final ValueChanged<bool?>? onToggleComplete;
  final bool animateOnComplete;
  final bool animateOnUncomplete;

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> {
  static const _completionDuration = Duration(milliseconds: 220);
  bool _isCompleting = false;
  Offset _slideOffset = Offset.zero;

  Future<void> _handleToggleComplete() async {
    if (widget.onToggleComplete == null) return;
    final willComplete = !widget.task.isCompleted;
    final shouldAnimate = (willComplete && widget.animateOnComplete) ||
        (!willComplete && widget.animateOnUncomplete);
    if (shouldAnimate) {
      if (_isCompleting) return;
      setState(() {
        _isCompleting = true;
        _slideOffset = willComplete ? const Offset(1.1, 0) : const Offset(-1.1, 0);
      });
      await Future.delayed(_completionDuration);
      widget.onToggleComplete?.call(willComplete);
      return;
    }
    widget.onToggleComplete?.call(willComplete);
  }

  @override
  Widget build(BuildContext context) {
    final dueDateTime = widget.task.dueDateTime;
    final now = DateTime.now();
    final isOverdue = dueDateTime != null &&
        !widget.task.isCompleted &&
        (widget.task.allDay
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
    String? dateText;
    String? timeText;
    if (dueDateTime != null) {
      dateText = DateFormat.MMMd().format(dueDateTime); // e.g. "Jan 21"
      timeText = widget.task.allDay ? null : formatShortTime(dueDateTime);
    }

    final bgColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0E1B26)
        : Theme.of(context).cardColor;
    int alphaFromOpacity(double opacity) {
      final normalized = opacity.clamp(0.0, 1.0);
      return (normalized * 255).round();
    }

    return AnimatedSlide(
      offset: _isCompleting ? _slideOffset : Offset.zero,
      duration: _completionDuration,
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: _isCompleting ? 0.0 : 1.0,
        duration: _completionDuration,
        curve: Curves.easeInOut,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: IgnorePointer(
              ignoring: _isCompleting,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      onTap: _handleToggleComplete,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.task.isCompleted
                              ? Theme.of(context).colorScheme.secondary
                              : Colors.transparent,
                          border: Border.all(
                            color: widget.task.isCompleted
                                ? Colors.transparent
                                : Theme.of(context)
                                    .dividerColor
                                    .withAlpha(alphaFromOpacity(0.6)),
                            width: 2,
                          ),
                        ),
                        child: widget.task.isCompleted
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.task.title,
                            overflow: TextOverflow.ellipsis,
                            style: widget.task.isCompleted
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
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (widget.task.tags.isNotEmpty)
                                TagChip(label: widget.task.tags.first),
                              if (widget.task.tags.isNotEmpty) const SizedBox(width: 10),
                              if (dueDateTime != null)
                                Row(
                                  children: [
                                    if (dateText != null)
                                      Text(
                                        dateText,
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.color
                                              ?.withAlpha(alphaFromOpacity(0.8)),
                                        ),
                                      ),
                                    if (dateText != null) const SizedBox(width: 8),
                                    if (timeText != null) ...[
                                      Icon(
                                        Icons.schedule_rounded,
                                        size: 16,
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color
                                            ?.withAlpha(alphaFromOpacity(0.7)),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        timeText!,
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
                                    ],
                                  ],
                                ),
                            ],
                          ),
                          if (widget.task.notes != null && widget.task.notes!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                widget.task.notes!,
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
                    if (isOverdue)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: overdueColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '!!!',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    if (widget.onDelete != null)
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context)
                              .iconTheme
                              .color
                              ?.withAlpha(alphaFromOpacity(0.7)),
                        ),
                        onPressed: widget.onDelete,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
