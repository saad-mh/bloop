import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task.dart';
import '../../providers/tab_provider.dart';
import '../../providers/task_provider.dart';
import '../../utils/date_utils.dart';
import '../../utils/due_status.dart';
import '../../utils/focus_pick.dart';
import '../theme/tokens.dart';
import '../widgets/bloop_icon_button.dart';
import '../widgets/floating_nav.dart';
import '../widgets/screen_header.dart';
import '../widgets/tag_pill.dart';
import 'focus_controller.dart';
import 'focus_widgets.dart' show FocusInk, FocusTimerDial;

/// The time the Ready screen judges "now" and "soon" by. Tests replace it.
final focusClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The redesigned Focus tab. One of three states: Ready (pick a task and
/// start), Running (the task, the time and three controls) and Time's up (is
/// the task finished?). No breaks, no session counts.
class FocusV2View extends ConsumerWidget {
  const FocusV2View({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(focusControllerProvider);
    if (controller.isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.isFinished) return const _TimesUp();
    if (controller.isSessionActive) return const _Running();
    return const _Ready();
  }
}

void _backToTasks(WidgetRef ref) =>
    ref.read(selectedTabProvider.notifier).select(tasksTabIndex);

Task? _taskById(WidgetRef ref, String? id) {
  if (id == null) return null;
  final tasks = ref.watch(taskListProvider).valueOrNull ?? const <Task>[];
  return tasks.where((t) => t.id == id).firstOrNull;
}

/// "4:00 PM", "All day" or "2 days late".
String _dueText(Task task, DateTime now) {
  final due = task.dueDateTime?.toLocal();
  if (due == null) return '';
  final status = DueStatus.of(task, now);
  if (status.kind == DueKind.late) return lateLabel(status.daysLate);
  return task.allDay ? 'All day' : formatShortTime(due);
}

String _minutes(int n) => n == 1 ? '1 minute' : '$n minutes';

/// Caption, task title and its first tag, centred.
class _TaskHeading extends StatelessWidget {
  const _TaskHeading({
    required this.caption,
    required this.title,
    required this.tag,
    required this.ink,
  });

  final String caption;
  final String? title;
  final String? tag;
  final FocusInk ink;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: BloopSpace.x8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            caption.toUpperCase(),
            textAlign: TextAlign.center,
            style: textTheme.labelMedium?.copyWith(
              color: ink.muted,
              letterSpacing: 0.8,
            ),
          ),
          if (title != null) ...[
            const SizedBox(height: BloopSpace.x2),
            Text(
              title!,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: textTheme.headlineMedium?.copyWith(
                color: ink.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (tag != null) ...[
            const SizedBox(height: BloopSpace.x2),
            TagPill(label: tag!, marker: TagPillMarker.dot),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Ready

class _Ready extends ConsumerStatefulWidget {
  const _Ready();

  @override
  ConsumerState<_Ready> createState() => _ReadyState();
}

class _ReadyState extends ConsumerState<_Ready> {
  /// The task chosen in the list; null until the user picks one.
  String? _pickedId;

  Future<void> _pick(List<Task> candidates, Task? current) async {
    final now = ref.read(focusClockProvider)();
    final chosen = await showModalBottomSheet<Task>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      builder: (context) => SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BloopSpace.x5,
                BloopSpace.x2,
                BloopSpace.x5,
                BloopSpace.x2,
              ),
              child: Text(
                'Choose a task',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final t in candidates)
                    ListTile(
                      title: Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(_dueText(t, now)),
                      selected: t.id == current?.id,
                      trailing: t.id == current?.id
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => Navigator.pop(context, t),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) setState(() => _pickedId = chosen.id);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(focusControllerProvider);
    final tokens = BloopTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final now = ref.watch(focusClockProvider)();
    final tasks = ref.watch(taskListProvider).valueOrNull ?? const <Task>[];
    final candidates = focusCandidates(tasks, now);
    final chosen =
        candidates.where((t) => t.id == _pickedId).firstOrNull ??
        defaultFocusTask(tasks, now);

    return Column(
      children: [
        const ScreenHeader(title: 'Focus'),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            BloopSpace.x4,
            BloopSpace.x3,
            BloopSpace.x4,
            0,
          ),
          child: chosen == null
              ? Text(
                  'Nothing due today. You can still start a session.',
                  style: textTheme.bodyMedium?.copyWith(color: tokens.muted),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        left: BloopSpace.x1,
                        bottom: BloopSpace.x2,
                      ),
                      child: Text(
                        'UP NEXT',
                        style: textTheme.labelMedium?.copyWith(
                          color: tokens.muted,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    _TaskSelector(
                      task: chosen,
                      dueText: _dueText(chosen, now),
                      onTap: candidates.length > 1
                          ? () => _pick(candidates, chosen)
                          : null,
                    ),
                  ],
                ),
        ),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: FocusTimerDial(
                remaining: controller.remaining,
                progress: 1,
                caption:
                    '${controller.focusDuration.inMinutes} min · set in '
                    'Settings',
                ink: FocusInk.themed(tokens),
              ),
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: () => chosen == null
              ? controller.startWithoutTask()
              : controller.startForTask(chosen),
          style: FilledButton.styleFrom(
            minimumSize: const Size(200, 56),
            shape: const StadiumBorder(),
          ),
          icon: const Icon(Icons.play_arrow, size: 20),
          label: const Text('Start'),
        ),
        if (chosen != null)
          TextButton(
            onPressed: controller.startWithoutTask,
            child: const Text('Focus without a task'),
          )
        else
          const SizedBox(height: kBloopMinTouchTarget),
        // Clear of the nav pill.
        SizedBox(height: floatingNavClearance(context)),
      ],
    );
  }
}

/// The "Up next" card: task title and when it is due. Taps open the list.
class _TaskSelector extends StatelessWidget {
  const _TaskSelector({
    required this.task,
    required this.dueText,
    required this.onTap,
  });

  final Task task;
  final String dueText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = BloopTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final tag = task.tags.firstOrNull;
    return Semantics(
      button: onTap != null,
      label: 'Task: ${task.title}',
      hint: onTap == null ? null : 'Choose another task',
      excludeSemantics: true,
      child: Material(
        color: tokens.raised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BloopRadii.lg),
          side: BorderSide(color: tokens.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BloopSpace.x4,
                vertical: BloopSpace.x3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: BloopSpace.x1),
                        Row(
                          children: [
                            if (dueText.isNotEmpty)
                              Text(
                                dueText,
                                style: textTheme.bodySmall?.copyWith(
                                  color: tokens.muted,
                                ),
                              ),
                            if (tag != null) ...[
                              const SizedBox(width: BloopSpace.x2),
                              Flexible(
                                child: TagPill(
                                  label: tag,
                                  marker: TagPillMarker.dot,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    Icon(Icons.keyboard_arrow_down, color: tokens.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- Running

class _Running extends ConsumerWidget {
  const _Running();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(focusControllerProvider);
    final tokens = BloopTokens.of(context);
    final ink = FocusInk.themed(tokens);
    final task = _taskById(ref, controller.taskId);
    final hasTask = controller.taskTitle != null;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(BloopSpace.x1),
            child: BloopIconButton(
              icon: Icons.keyboard_arrow_down,
              tooltip: 'Minimise to Tasks',
              onPressed: () => _backToTasks(ref),
            ),
          ),
        ),
        _TaskHeading(
          caption: hasTask ? 'Focusing on' : 'Focus session',
          title: controller.taskTitle,
          tag: task?.tags.firstOrNull,
          ink: ink,
        ),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: FocusTimerDial(
                remaining: controller.remaining,
                progress: controller.progress,
                paused: !controller.isRunning,
                caption:
                    'remaining of ${controller.sessionLength.inMinutes} min',
                ink: ink,
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: BloopSpace.x3),
              child: _RoundControl(
                icon: Icons.stop_outlined,
                label: 'End',
                onPressed: controller.endSession,
              ),
            ),
            const SizedBox(width: BloopSpace.x4),
            _RoundControl(
              icon: controller.isRunning ? Icons.pause : Icons.play_arrow,
              label: controller.isRunning ? 'Pause' : 'Resume',
              primary: true,
              onPressed: controller.isRunning
                  ? controller.pause
                  : controller.start,
            ),
            const SizedBox(width: BloopSpace.x4),
            // Completing needs a task; keep the gap so Pause stays centred.
            Padding(
              padding: const EdgeInsets.only(top: BloopSpace.x3),
              child: hasTask
                  ? _RoundControl(
                      icon: Icons.check,
                      label: 'Done',
                      onPressed: () {
                        controller.completeTask();
                        _backToTasks(ref);
                      },
                    )
                  : const SizedBox(width: _RoundControl.slotWidth),
            ),
          ],
        ),
        SizedBox(
          height: BloopSpace.x10 + MediaQuery.viewPaddingOf(context).bottom,
        ),
      ],
    );
  }
}

/// A round button with its label underneath. [primary] is the large filled one.
class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  static const double slotWidth = 88;

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final tokens = BloopTokens.of(context);
    final size = primary ? 80.0 : 56.0;
    return SizedBox(
      width: slotWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: label,
            excludeSemantics: true,
            onTap: onPressed,
            child: Material(
              color: primary ? tokens.action : tokens.raised,
              shape: CircleBorder(
                side: primary
                    ? BorderSide.none
                    : BorderSide(color: tokens.muted, width: 1.5),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: SizedBox.square(
                  dimension: size,
                  child: Icon(
                    icon,
                    size: primary ? 32 : 22,
                    color: primary ? tokens.onAction : tokens.ink,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: BloopSpace.x2 - 2),
          ExcludeSemantics(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: primary ? tokens.ink : tokens.muted,
                fontWeight: primary ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- Time's up

class _TimesUp extends ConsumerWidget {
  const _TimesUp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(focusControllerProvider);
    final tokens = BloopTokens.of(context);
    final ink = FocusInk.themed(tokens);
    final task = _taskById(ref, controller.taskId);
    final hasTask = controller.taskTitle != null;
    return Column(
      children: [
        const SizedBox(height: kBloopMinTouchTarget + BloopSpace.x2),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: 1,
                          strokeWidth: 6,
                          color: ink.ink,
                          year2023: false,
                        ),
                        Icon(Icons.check, size: 64, color: ink.ink),
                      ],
                    ),
                  ),
                  const SizedBox(height: BloopSpace.x6),
                  _TaskHeading(
                    caption:
                        '${_minutes(controller.sessionLength.inMinutes)} done',
                    title: controller.taskTitle,
                    tag: task?.tags.firstOrNull,
                    ink: ink,
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            BloopSpace.x4,
            0,
            BloopSpace.x4,
            BloopSpace.x6 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasTask) ...[
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () {
                    controller.completeTask();
                    _backToTasks(ref);
                  },
                  child: const Text('Mark task done'),
                ),
                const SizedBox(height: BloopSpace.x2),
              ],
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: controller.keepGoing,
                child: Text(
                  'Keep going · ${FocusController.keepGoingExtra.inMinutes} '
                  'more min',
                ),
              ),
              TextButton(
                onPressed: () {
                  controller.dismissFinished();
                  _backToTasks(ref);
                },
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
