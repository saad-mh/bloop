import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Title row at the top of a screen: optional leading button, the title in
/// the heading face, and trailing actions. Use [BloopIconButton] for buttons
/// so they keep the 48dp touch target.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
  });

  final String title;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kBloopMinTouchTarget),
      child: Padding(
        padding: EdgeInsets.only(
          left: leading == null ? BloopSpace.x4 : BloopSpace.x2,
          right: BloopSpace.x2,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: BloopSpace.x1),
            ],
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}
