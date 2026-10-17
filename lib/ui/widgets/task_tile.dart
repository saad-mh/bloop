import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/task.dart';
import '../../utils/date_utils.dart';
import '../theme/tokens.dart';
import 'tag_pill.dart';

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
    final tokens = BloopTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    String? dateText;
    String? timeText;
    if (dueDateTime != null) {
      dateText = DateFormat.MMMd().format(dueDateTime); // e.g. "Jan 21"
      timeText = widget.task.allDay ? null : formatShortTime(dueDateTime);
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
            onLongPress: widget.onTap,
            borderRadius: BorderRadius.circular(BloopRadii.lg),
            child: IgnorePointer(
              ignoring: _isCompleting,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: tokens.raised,
                  borderRadius: BorderRadius.circular(BloopRadii.lg),
                  border: Border.all(color: tokens.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _handleToggleComplete,
                        onLongPress: widget.onTap,
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.task.isCompleted
                                    ? tokens.action
                                    : Colors.transparent,
                                border: Border.all(
                                  color: widget.task.isCompleted
                                      ? Colors.transparent
                                      : tokens.muted,
                                  width: 2,
                                ),
                              ),
                              child: widget.task.isCompleted
                                  ? Icon(Icons.check, size: 16, color: tokens.onAction)
                                  : null,
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
                                        ? textTheme.titleMedium?.copyWith(
                                            decoration: TextDecoration.lineThrough,
                                            color: tokens.muted,
                                          )
                                        : textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  // Wraps rather than clips: with the overdue badge and
                                  // delete button there is little room on narrow phones
                                  // or at large text sizes.
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      if (widget.task.tags.isNotEmpty)
                                        TagPill(label: widget.task.tags.first),
                                      if (dateText != null)
                                        Text(
                                          dateText,
                                          style: textTheme.bodyMedium
                                              ?.copyWith(color: tokens.muted),
                                        ),
                                      if (timeText != null)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.schedule_rounded,
                                              size: 16,
                                              color: tokens.muted,
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                timeText,
                                                overflow: TextOverflow.ellipsis,
                                                style: textTheme.bodyMedium?.copyWith(
                                                  color: isOverdue
                                                      ? tokens.ink
                                                      : tokens.muted,
                                                  fontWeight:
                                                      isOverdue ? FontWeight.w600 : null,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  if (widget.task.notes != null &&
                                      widget.task.notes!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        widget.task.notes!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.bodySmall
                                            ?.copyWith(color: tokens.muted),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isOverdue)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: tokens.action,
                            borderRadius: BorderRadius.circular(BloopRadii.lg),
                          ),
                          child: Text(
                            '!!!',
                            style: textTheme.labelLarge?.copyWith(
                              color: tokens.onAction,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    if (widget.onDelete != null)
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: tokens.muted,
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
