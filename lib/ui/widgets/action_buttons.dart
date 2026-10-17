import 'package:flutter/material.dart';

/// Filled call-to-action. Styling comes from the theme's filled button.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Stretch to the full available width. Needs a bounded width, so don't use
  /// it directly inside a [Row] or a horizontal scroll view.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = icon == null
        ? FilledButton(onPressed: onPressed, child: Text(label))
        : FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          );
    return _expanded(button, expand);
  }
}

/// Secondary action with an outline. Styling comes from the theme's outlined
/// button.
class OutlineActionButton extends StatelessWidget {
  const OutlineActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Stretch to the full available width. Needs a bounded width, so don't use
  /// it directly inside a [Row] or a horizontal scroll view.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = icon == null
        ? OutlinedButton(onPressed: onPressed, child: Text(label))
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          );
    return _expanded(button, expand);
  }
}

Widget _expanded(Widget button, bool expand) =>
    expand ? SizedBox(width: double.infinity, child: button) : button;
