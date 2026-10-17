import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../theme/tokens.dart';

class PriorityIndicator extends StatelessWidget {
  const PriorityIndicator({super.key, required this.priority});

  final Priority priority;

  @override
  Widget build(BuildContext context) {
    // Monochrome: priority reads as dot weight (solid / half / ring), not hue.
    final tokens = BloopTokens.of(context);
    final (fill, ring) = switch (priority) {
      Priority.high => (tokens.ink, tokens.ink),
      Priority.medium => (tokens.muted, tokens.muted),
      Priority.low => (Colors.transparent, tokens.muted),
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: 1.5),
      ),
    );
  }
}
