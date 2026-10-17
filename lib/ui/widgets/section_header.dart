import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// List section title: label, a lighter count and an optional date, with a
/// chevron when the section can be collapsed.
///
/// The widget is controlled: pass [expanded] and [onToggle]. Leave [onToggle]
/// null for a plain, non-collapsible header.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.label,
    this.count,
    this.date,
    this.expanded = true,
    this.onToggle,
  });

  final String label;
  final int? count;

  /// Already formatted, e.g. "Sat, Oct 17".
  final String? date;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = BloopTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final collapsible = onToggle != null;

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final rowWidth = constraints.maxWidth;
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kBloopMinTouchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: BloopSpace.x4),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall,
                        ),
                      ),
                      if (count != null) ...[
                        const SizedBox(width: BloopSpace.x2),
                        Text(
                          '$count',
                          style: textTheme.titleSmall?.copyWith(
                            color: tokens.muted,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (date != null)
                  // Natural width so it hugs the right edge, capped at half the
                  // row so a long date cannot push the label out.
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: rowWidth / 2),
                    child: Text(
                      date!,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(color: tokens.muted),
                    ),
                  ),
                if (collapsible) ...[
                  const SizedBox(width: BloopSpace.x2),
                  AnimatedRotation(
                    turns: expanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      Icons.expand_more,
                      size: 20,
                      color: tokens.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );

    return Semantics(
      header: true,
      button: collapsible,
      expanded: collapsible ? expanded : null,
      label: [
        label,
        if (count != null) '$count',
        if (date != null) date!,
      ].join(', '),
      excludeSemantics: true,
      onTap: onToggle,
      child: collapsible ? InkWell(onTap: onToggle, child: content) : content,
    );
  }
}
