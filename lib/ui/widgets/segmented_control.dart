import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// One option of a [SegmentedControl].
@immutable
class Segment<T> {
  const Segment({required this.value, required this.label});

  final T value;
  final String label;
}

/// Single-choice control that shows every option at once, e.g. Low / Normal /
/// High or 15 / 25 / 45 / Custom.
///
/// The selected segment is filled and bold, so selection does not depend on
/// colour alone.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<Segment<T>> segments;
  final T selected;
  final ValueChanged<T>? onChanged;

  // Segments keep the full touch target, so the track grows by its padding
  // and 1dp border on each side.
  static const double _height = kBloopMinTouchTarget + 2 * BloopSpace.x1 + 2;

  @override
  Widget build(BuildContext context) {
    assert(segments.length >= 2, 'A segmented control needs two or more.');
    final tokens = BloopTokens.of(context);

    return Semantics(
      container: true,
      child: Container(
        height: _height,
        padding: const EdgeInsets.all(BloopSpace.x1),
        decoration: BoxDecoration(
          color: tokens.sunken,
          borderRadius: BorderRadius.circular(BloopRadii.md),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          children: [
            for (final segment in segments)
              Expanded(
                child: _SegmentButton(
                  label: segment.label,
                  selected: segment.value == selected,
                  onTap: onChanged == null
                      ? null
                      : () => onChanged!(segment.value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = BloopTokens.of(context);
    final enabled = onTap != null;
    final radius = BorderRadius.circular(BloopRadii.sm);
    final foreground = !enabled
        ? tokens.muted
        : selected
        ? tokens.onAction
        : tokens.ink;

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      enabled: enabled,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: Material(
        color: selected ? tokens.action : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: foreground,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
