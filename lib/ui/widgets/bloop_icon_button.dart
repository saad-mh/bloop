import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Icon-only button with a 48dp touch target. [tooltip] is required because
/// it is also the accessibility label.
class BloopIconButton extends StatelessWidget {
  const BloopIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: kBloopMinTouchTarget,
      child: IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
