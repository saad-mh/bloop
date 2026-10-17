import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Selectable chip for filters and options.
///
/// Selection never relies on colour alone: a selected chip is filled with the
/// action colour, shows a tick and has a heavier outline.
class BloopChoiceChip extends StatelessWidget {
  const BloopChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  static const double _height = 32;

  @override
  Widget build(BuildContext context) {
    final tokens = BloopTokens.of(context);
    final enabled = onSelected != null;
    final foreground = !enabled
        ? tokens.muted
        : selected
        ? tokens.onAction
        : tokens.ink;
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
        borderRadius: BorderRadius.circular(BloopRadii.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kBloopMinTouchTarget),
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: _height,
              padding: const EdgeInsets.symmetric(horizontal: BloopSpace.x3),
              decoration: BoxDecoration(
                color: selected ? tokens.action : Colors.transparent,
                borderRadius: BorderRadius.circular(BloopRadii.md),
                border: Border.all(
                  color: selected ? tokens.action : tokens.border,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    Icon(Icons.check, size: 16, color: foreground),
                    const SizedBox(width: BloopSpace.x1),
                  ],
                  Text(label, style: style),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
