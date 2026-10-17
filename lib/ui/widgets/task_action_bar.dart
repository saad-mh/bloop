import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The four actions under an expanded task row: Focus, Snooze 1h, Tomorrow
/// and Edit. Wraps onto a second line at large text sizes instead of cutting
/// labels short.
class TaskActionBar extends StatelessWidget {
  const TaskActionBar({
    super.key,
    required this.focusMinutes,
    required this.onFocus,
    required this.onSnooze,
    required this.onTomorrow,
    required this.onEdit,
  });

  /// Length of the session the Focus button starts.
  final int focusMinutes;
  final VoidCallback onFocus;
  final VoidCallback onSnooze;
  final VoidCallback onTomorrow;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final tokens = BloopTokens.of(context);
    // The theme's buttons are sized for full-width use; these share a row.
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: BloopSpace.x3),
      side: BorderSide(color: tokens.muted),
      backgroundColor: tokens.raised,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BloopSpace.x4,
        0,
        BloopSpace.x3,
        BloopSpace.x2,
      ),
      child: Wrap(
        spacing: BloopSpace.x2,
        runSpacing: BloopSpace.x2,
        children: [
          OutlinedButton.icon(
            style: style,
            onPressed: onFocus,
            icon: const Icon(Icons.adjust, size: 16),
            label: Text('Focus ${focusMinutes}m'),
          ),
          OutlinedButton(
            style: style,
            onPressed: onSnooze,
            child: const Text('Snooze 1h'),
          ),
          OutlinedButton(
            style: style,
            onPressed: onTomorrow,
            child: const Text('Tomorrow'),
          ),
          OutlinedButton(
            style: style,
            onPressed: onEdit,
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }
}
