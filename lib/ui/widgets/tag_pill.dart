import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// What sits before a [TagPill]'s label.
enum TagPillMarker { hash, dot }

/// Monochrome tag: outlined, with a hash or a small dot before the label.
///
/// Read-only by default. Pass [onTap] to make it a button; the hit area then
/// grows to the minimum touch target while the pill itself stays small.
class TagPill extends StatelessWidget {
  const TagPill({
    super.key,
    required this.label,
    this.marker = TagPillMarker.hash,
    this.onTap,
  });

  final String label;
  final TagPillMarker marker;
  final VoidCallback? onTap;

  static const double _dotSize = 6;

  @override
  Widget build(BuildContext context) {
    final tokens = BloopTokens.of(context);
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: tokens.ink);

    final pill = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BloopSpace.x2,
        vertical: BloopSpace.x1,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BloopRadii.sm),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: switch (marker) {
              TagPillMarker.hash => Text(
                '#',
                style: labelStyle?.copyWith(color: tokens.muted),
              ),
              TagPillMarker.dot => Container(
                width: _dotSize,
                height: _dotSize,
                decoration: BoxDecoration(
                  color: tokens.muted,
                  shape: BoxShape.circle,
                ),
              ),
            },
          ),
          const SizedBox(width: BloopSpace.x1),
          Flexible(
            child: Text(
              label,
              style: labelStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return pill;

    return Semantics(
      button: true,
      label: 'Tag $label',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(BloopRadii.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: kBloopMinTouchTarget,
            minHeight: kBloopMinTouchTarget,
          ),
          child: Center(widthFactor: 1, child: pill),
        ),
      ),
    );
  }
}
