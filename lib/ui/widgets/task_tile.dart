import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/task.dart';
import '../../utils/date_utils.dart';
import '../../utils/due_status.dart';
import '../theme/tokens.dart';
import 'tag_pill.dart';

/// One task in a list: complete circle, title, a meta line (when + tag), then
/// a flag for high priority and a bell when a reminder is set.
///
/// The circle is the only way to complete a task. Tapping the row opens it,
/// and swiping it away deletes it when [onDelete] is set.
class TaskTile extends StatefulWidget {
  const TaskTile({
    super.key,
    required this.task,
    this.onToggleComplete,
    this.onTap,
    this.onDelete,
    this.animateOnComplete = false,
    this.animateOnUncomplete = false,
    this.now = DateTime.now,
  });

  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final ValueChanged<bool?>? onToggleComplete;
  final bool animateOnComplete;
  final bool animateOnUncomplete;

  /// Clock for the NOW / soon / late wording; replaced in tests.
  final DateTime Function() now;

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> {
  static const _completionDuration = Duration(milliseconds: 220);
  static const _iconSize = 18.0;

  bool _isCompleting = false;
  Offset _slideOffset = Offset.zero;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _scheduleTick();
  }

  @override
  void didUpdateWidget(TaskTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleTick();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Rebuilds on the minute so "In 18 min" counts down and a row moves into
  /// or out of NOW without waiting for the list to change.
  void _scheduleTick() {
    _ticker?.cancel();
    final task = widget.task;
    if (task.dueDateTime == null || task.isCompleted || task.allDay) return;
    final now = widget.now();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _ticker = Timer(nextMinute.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _scheduleTick();
    });
  }

  Future<void> _handleToggleComplete() async {
    if (widget.onToggleComplete == null) return;
    final willComplete = !widget.task.isCompleted;
    final shouldAnimate =
        (willComplete && widget.animateOnComplete) ||
        (!willComplete && widget.animateOnUncomplete);
    if (shouldAnimate) {
      if (_isCompleting) return;
      setState(() {
        _isCompleting = true;
        _slideOffset = willComplete
            ? const Offset(1.1, 0)
            : const Offset(-1.1, 0);
      });
      await Future.delayed(_completionDuration);
      widget.onToggleComplete?.call(willComplete);
      return;
    }
    widget.onToggleComplete?.call(willComplete);
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final tokens = BloopTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final now = widget.now();
    final status = task.isCompleted
        ? const DueStatus(DueKind.scheduled)
        : DueStatus.of(task, now);

    final isLate = status.kind == DueKind.late;
    final emphasised = status.kind == DueKind.now || isLate;
    final fill = switch (status.kind) {
      DueKind.now => tokens.border,
      DueKind.soon => Color.lerp(tokens.raised, tokens.border, 0.5),
      _ => null,
    };

    final titleStyle = textTheme.bodyLarge?.copyWith(
      color: task.isCompleted ? tokens.muted : tokens.ink,
      fontWeight: emphasised ? FontWeight.w700 : FontWeight.w400,
      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
    );
    final metaStyle = textTheme.bodySmall?.copyWith(
      color: tokens.muted,
      fontWeight: FontWeight.w500,
    );
    final strongMeta = metaStyle?.copyWith(
      color: tokens.ink,
      fontWeight: FontWeight.w700,
    );

    final row = Material(
      color: fill ?? Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onTap,
        child: IgnorePointer(
          ignoring: _isCompleting,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.only(
              left: BloopSpace.x1,
              right: BloopSpace.x4,
            ),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.border)),
            ),
            child: Row(
              children: [
                _CompleteCircle(
                  completed: task.isCompleted,
                  onTap: widget.onToggleComplete == null
                      ? null
                      : _handleToggleComplete,
                ),
                const SizedBox(width: BloopSpace.x1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: BloopSpace.x2,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ),
                        // Wraps rather than clips: a long tag plus a date and
                        // time has little room on a 320dp phone or at large
                        // text sizes.
                        Wrap(
                          spacing: BloopSpace.x2,
                          runSpacing: BloopSpace.x1,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _when(
                              task,
                              status,
                              now,
                              metaStyle,
                              strongMeta,
                              tokens,
                            ),
                            if (task.tags.isNotEmpty)
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 160,
                                ),
                                child: TagPill(label: task.tags.first),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (task.priority == Priority.high && !task.isCompleted)
                  Padding(
                    padding: const EdgeInsets.only(left: BloopSpace.x3),
                    child: Semantics(
                      label: 'High priority',
                      child: Icon(
                        // Late is told by weight, not colour: a filled flag.
                        isLate ? Icons.flag : Icons.flag_outlined,
                        size: _iconSize,
                        color: tokens.ink,
                      ),
                    ),
                  ),
                if (task.remindersBefore.isNotEmpty && !task.isCompleted)
                  Padding(
                    padding: const EdgeInsets.only(left: BloopSpace.x3),
                    child: Semantics(
                      label: 'Reminder set',
                      child: Icon(
                        Icons.notifications_none_rounded,
                        size: _iconSize,
                        color: tokens.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final swipeable = widget.onDelete == null
        ? row
        : Dismissible(
            key: ValueKey('dismiss-${task.id}'),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => widget.onDelete?.call(),
            background: Container(
              color: tokens.error,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: BloopSpace.x6),
              child: Icon(Icons.delete_outline, color: tokens.onError),
            ),
            child: row,
          );

    return AnimatedSlide(
      offset: _isCompleting ? _slideOffset : Offset.zero,
      duration: _completionDuration,
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: _isCompleting ? 0.0 : 1.0,
        duration: _completionDuration,
        curve: Curves.easeInOut,
        child: swipeable,
      ),
    );
  }

  /// The when-part of the meta line as one rich [Text], so it ellipsises
  /// instead of overflowing when the Wrap gives it little room.
  Widget _when(
    Task task,
    DueStatus status,
    DateTime now,
    TextStyle? meta,
    TextStyle? strong,
    BloopTokens tokens,
  ) {
    final due = task.dueDateTime?.toLocal();
    final time = due == null || task.allDay ? null : formatShortTime(due);
    final date = due == null ? null : DateFormat('EEE d MMM').format(due);

    final spans = <InlineSpan>[];
    if (task.isCompleted) {
      if (date != null) {
        spans.add(TextSpan(text: time == null ? date : '$date · $time'));
      }
    } else {
      switch (status.kind) {
        case DueKind.anytime:
          spans.add(const TextSpan(text: 'Anytime'));
        case DueKind.late:
          spans.addAll([
            TextSpan(text: '$date · '),
            TextSpan(text: lateLabel(status.daysLate), style: strong),
          ]);
        case DueKind.now:
          spans.addAll([
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: BloopSpace.x2 - 2,
                ),
                decoration: BoxDecoration(
                  color: tokens.action,
                  borderRadius: BorderRadius.circular(BloopRadii.sm),
                ),
                child: Text(
                  'NOW',
                  style: meta?.copyWith(
                    color: tokens.onAction,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
            TextSpan(text: '  $time'),
          ]);
        case DueKind.soon:
          spans.addAll([
            TextSpan(text: 'In ${status.minutesAhead} min', style: strong),
            TextSpan(text: ' · $time'),
          ]);
        case DueKind.scheduled:
          if (isSameDay(due!, now)) {
            spans.add(TextSpan(text: time ?? 'Today'));
          } else {
            spans.add(TextSpan(text: time == null ? date : '$date · $time'));
          }
      }
    }

    return Text.rich(
      TextSpan(style: meta, children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Circle checkbox with a 48dp hit area around a 24dp visual.
class _CompleteCircle extends StatelessWidget {
  const _CompleteCircle({required this.completed, required this.onTap});

  final bool completed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = BloopTokens.of(context);
    return Semantics(
      label: completed ? 'Mark as not done' : 'Complete task',
      button: true,
      checked: completed,
      excludeSemantics: true,
      onTap: onTap,
      child: InkResponse(
        onTap: onTap,
        radius: kBloopMinTouchTarget / 2,
        child: SizedBox(
          width: kBloopMinTouchTarget,
          height: kBloopMinTouchTarget,
          child: Center(
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed ? tokens.action : Colors.transparent,
                border: Border.all(
                  color: completed ? tokens.action : tokens.muted,
                  width: 1.5,
                ),
              ),
              child: completed
                  ? Icon(Icons.check, size: 16, color: tokens.onAction)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
