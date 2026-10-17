import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Selectable chip for filters and options.
///
/// Selection never relies on colour alone: a selected chip is filled with the
/// action colour, shows a tick and has a heavier outline.
///
/// An optional [icon] leads an unselected chip; a selected one shows the tick
/// in its place.
class BloopChoiceChip extends StatelessWidget {
  const BloopChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;

  static const double _height = 32;

  @override
  Widget build(BuildContext context) {
    final tokens = BloopTokens.of(context);
    final enabled = onSelected != null;
    // A disabled chip drops the action fill so its text stays readable.
    final filled = selected && enabled;
    final foreground = !enabled
        ? tokens.muted
        : selected
        ? tokens.onAction
        : tokens.ink;
    final outline = filled
        ? tokens.action
        : selected
        ? tokens.muted
        : tokens.border;
    final radius = BorderRadius.circular(BloopRadii.md);
    final style = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(color: foreground);

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      excludeSemantics: true,
      label: label,
      onTap: enabled ? () => onSelected!(!selected) : null,
      child: InkWell(
        onTap: enabled ? () => onSelected!(!selected) : null,
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kBloopMinTouchTarget),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            // Ink paints the fill on the Material so the tap ripple shows
            // above it, including on a selected chip.
            child: Ink(
              height: _height,
              padding: const EdgeInsets.symmetric(horizontal: BloopSpace.x3),
              decoration: BoxDecoration(
                color: filled ? tokens.action : Colors.transparent,
                borderRadius: radius,
                border: Border.all(color: outline, width: selected ? 2 : 1),
              ),
              // See TagPill: Flexible needs a bounded width.
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final text = Text(
                    label,
                    style: style,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected || icon != null) ...[
                        Icon(
                          selected ? Icons.check : icon,
                          size: 16,
                          color: foreground,
                        ),
                        const SizedBox(width: BloopSpace.x1),
                      ],
                      constraints.hasBoundedWidth
                          ? Flexible(child: text)
                          : text,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
