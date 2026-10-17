import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Height of the pill and of the New task button.
const double kFloatingNavHeight = 64;

/// Gap between the nav group and the bottom safe-area edge.
const double kFloatingNavBottomMargin = BloopSpace.x3;

/// Space a scrolling list needs at its end so the last row clears the nav.
/// Includes the system inset, so use it where that inset isn't already
/// consumed by a [SafeArea].
double floatingNavClearance(BuildContext context) =>
    kFloatingNavHeight +
    kFloatingNavBottomMargin +
    BloopSpace.x4 +
    MediaQuery.viewPaddingOf(context).bottom;

/// A destination in the pill.
class FloatingNavDestination {
  const FloatingNavDestination({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Floating bottom navigation: a pill holding the destinations, with a round
/// New task button beside it. Centred as one group; place it with
/// [FloatingNavLayer] so it sits above the gesture bar.
class FloatingNav extends StatelessWidget {
  const FloatingNav({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.onNewTask,
  });

  final List<FloatingNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onNewTask;

  @override
  Widget build(BuildContext context) {
    final t = BloopTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: kFloatingNavHeight,
          padding: const EdgeInsets.symmetric(horizontal: BloopSpace.x2),
          decoration: ShapeDecoration(
            color: t.raised,
            shape: StadiumBorder(side: BorderSide(color: t.border, width: 1.5)),
            shadows: _shadows,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < destinations.length; i++) ...[
                if (i > 0) const SizedBox(width: BloopSpace.x1),
                _Segment(
                  destination: destinations[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelected(i),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: BloopSpace.x3),
        DecoratedBox(
          decoration: ShapeDecoration(
            color: t.action,
            shape: const CircleBorder(),
            shadows: _shadows,
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'New task',
              onPressed: onNewTask,
              color: t.onAction,
              iconSize: 28,
              constraints: const BoxConstraints.tightFor(
                width: kFloatingNavHeight,
                height: kFloatingNavHeight,
              ),
              icon: const Icon(Icons.add),
            ),
          ),
        ),
      ],
    );
  }

  static const _shadows = [
    BoxShadow(color: Color(0x2E000000), blurRadius: 10, offset: Offset(0, 3)),
  ];
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final FloatingNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = BloopTokens.of(context);
    final foreground = selected ? t.onAction : t.ink;
    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: destination.label,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            // Sizes to its label so large text scales don't overflow.
            constraints: const BoxConstraints(
              minWidth: 96,
              minHeight: kBloopMinTouchTarget,
            ),
            padding: const EdgeInsets.symmetric(horizontal: BloopSpace.x4),
            decoration: ShapeDecoration(
              color: selected ? t.action : Colors.transparent,
              shape: const StadiumBorder(),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(destination.icon, size: 20, color: foreground),
                const SizedBox(width: BloopSpace.x1 + 2),
                Text(
                  destination.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays [nav] over [child], pinned above the bottom system inset, with a fade
/// scrim so content scrolling underneath stays legible. The child extends
/// behind the scrim; give scrolling lists [floatingNavClearance] of bottom
/// padding.
class FloatingNavLayer extends StatelessWidget {
  const FloatingNavLayer({super.key, required this.child, required this.nav});

  final Widget child;
  final Widget nav;

  static const double _scrimHeight = 120;

  @override
  Widget build(BuildContext context) {
    final surface = BloopTokens.of(context).surface;
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: _scrimHeight + inset,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  // Fade from the same colour at zero alpha, not from
                  // transparent black, which would muddy the gradient.
                  colors: [surface.withValues(alpha: 0), surface],
                  stops: const [0, 0.72],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: kFloatingNavBottomMargin + inset,
          child: Center(child: nav),
        ),
      ],
    );
  }
}
