import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The system permissions Bloop asks for on first launch.
enum PermissionKind { notifications, exactAlarm }

/// What each prompt says. Kept short on purpose: an icon, one headline, one
/// line of why, and a button that names what it will do.
class _PromptCopy {
  const _PromptCopy({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.previewTitle,
    required this.previewDetail,
    required this.previewIcon,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final String previewTitle;
  final String previewDetail;
  final IconData previewIcon;
}

const _copy = {
  PermissionKind.notifications: _PromptCopy(
    icon: Icons.notifications_none,
    title: 'Get nudged when it counts',
    body: 'Bloop pings you when a task is due.',
    action: 'Allow notifications',
    previewTitle: 'Robotics Club budget sheet',
    previewDetail: 'Due now',
    previewIcon: Icons.check_circle_outline,
  ),
  PermissionKind.exactAlarm: _PromptCopy(
    icon: Icons.alarm,
    title: 'Right on the minute',
    body: 'Without this, Android can hold reminders back.',
    action: 'Allow exact timing',
    previewTitle: '4:00 PM',
    previewDetail: 'Reminder lands at 4:00, not 4:07',
    previewIcon: Icons.schedule,
  ),
};

/// Asks about one permission in a bottom sheet. Resolves to true when the user
/// taps the main button and false for "Not now" or any other way of closing it.
///
/// [step] is 1-based; with more than one [steps] the sheet shows where the
/// user is in the run.
Future<bool> showPermissionPrompt(
  BuildContext context, {
  required PermissionKind kind,
  int step = 1,
  int steps = 1,
}) async {
  final allowed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => PermissionPrompt(kind: kind, step: step, steps: steps),
  );
  return allowed ?? false;
}

class PermissionPrompt extends StatelessWidget {
  const PermissionPrompt({
    super.key,
    required this.kind,
    this.step = 1,
    this.steps = 1,
  });

  final PermissionKind kind;
  final int step;
  final int steps;

  @override
  Widget build(BuildContext context) {
    final copy = _copy[kind]!;
    final tokens = BloopTokens.of(context);
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BloopSpace.x6,
          BloopSpace.x6,
          BloopSpace.x6,
          BloopSpace.x4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (steps > 1) _StepDots(step: step, steps: steps),
            const SizedBox(height: BloopSpace.x6),
            Center(child: _IconRing(icon: copy.icon)),
            const SizedBox(height: BloopSpace.x6),
            Text(
              copy.title,
              textAlign: TextAlign.center,
              style: text.headlineSmall,
            ),
            const SizedBox(height: BloopSpace.x2),
            Text(
              copy.body,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: tokens.muted),
            ),
            const SizedBox(height: BloopSpace.x6),
            ExcludeSemantics(child: _Preview(copy: copy)),
            const SizedBox(height: BloopSpace.x6),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(copy.action),
            ),
            const SizedBox(height: BloopSpace.x1),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Filled up to the current step, hollow after it.
class _StepDots extends StatelessWidget {
  const _StepDots({required this.step, required this.steps});

  final int step;
  final int steps;

  @override
  Widget build(BuildContext context) {
    final tokens = BloopTokens.of(context);
    return Semantics(
      label: 'Step $step of $steps',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 1; i <= steps; i++)
            Container(
              width: i == step ? 20 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: BloopSpace.x1 / 2),
              decoration: BoxDecoration(
                color: i <= step ? tokens.action : tokens.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}

/// The outlined circle used on the Focus screen, with the permission's icon.
class _IconRing extends StatelessWidget {
  const _IconRing({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = BloopTokens.of(context);
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: tokens.ink, width: 3),
      ),
      child: Icon(icon, size: 40, color: tokens.ink),
    );
  }
}

/// A small mock of what the permission buys, so the sheet shows rather than
/// tells.
class _Preview extends StatelessWidget {
  const _Preview({required this.copy});

  final _PromptCopy copy;

  @override
  Widget build(BuildContext context) {
    final tokens = BloopTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(BloopSpace.x3),
      decoration: BoxDecoration(
        color: tokens.sunken,
        borderRadius: BorderRadius.circular(BloopRadii.lg),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tokens.action,
              borderRadius: BorderRadius.circular(BloopRadii.md),
            ),
            child: Icon(copy.previewIcon, size: 20, color: tokens.onAction),
          ),
          const SizedBox(width: BloopSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.previewTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
                ),
                Text(
                  copy.previewDetail,
                  style: text.bodySmall?.copyWith(color: tokens.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
