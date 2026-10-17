import 'package:bloop/ui/theme/tokens.dart';
import 'package:bloop/ui/widgets/bloop_icon_button.dart';
import 'package:bloop/ui/widgets/screen_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_app.dart';

void main() {
  testWidgets('title uses the heading face', (tester) async {
    await pumpThemed(tester, const ScreenHeader(title: 'Tasks'));

    final text = tester.widget<Text>(find.text('Tasks'));
    expect(text.style?.fontFamily, BloopFonts.heading);
  });

  testWidgets('is exposed as a header', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpThemed(tester, const ScreenHeader(title: 'Tasks'));

    expect(
      tester.getSemantics(find.text('Tasks')),
      matchesSemantics(label: 'Tasks', isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('renders leading and trailing buttons that fire', (tester) async {
    final taps = <String>[];
    await pumpThemed(
      tester,
      ScreenHeader(
        title: 'Tasks',
        leading: BloopIconButton(
          icon: Icons.arrow_back,
          tooltip: 'Back',
          onPressed: () => taps.add('back'),
        ),
        actions: [
          BloopIconButton(
            icon: Icons.settings,
            tooltip: 'Settings',
            onPressed: () => taps.add('settings'),
          ),
        ],
      ),
    );

    await tester.tap(find.byTooltip('Back'));
    await tester.tap(find.byTooltip('Settings'));
    expect(taps, ['back', 'settings']);
  });

  testWidgets('icon buttons are 48dp', (tester) async {
    await pumpThemed(
      tester,
      BloopIconButton(
        icon: Icons.settings,
        tooltip: 'Settings',
        onPressed: () {},
      ),
    );

    expect(
      tester.getSize(find.byType(BloopIconButton)),
      const Size.square(kBloopMinTouchTarget),
    );
  });

  testWidgets('icon button tooltip is its accessibility label', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpThemed(
      tester,
      BloopIconButton(
        icon: Icons.settings,
        tooltip: 'Settings',
        onPressed: () {},
      ),
    );

    final node = tester.getSemantics(find.byType(IconButton));
    expect('${node.label} ${node.tooltip}', contains('Settings'));
    handle.dispose();
  });

  testWidgets('header keeps at least the touch-target height', (tester) async {
    await pumpThemed(tester, const ScreenHeader(title: 'Tasks'));

    expect(
      tester.getSize(find.byType(ScreenHeader)).height,
      greaterThanOrEqualTo(kBloopMinTouchTarget),
    );
  });

  testWidgets('long title ellipsises beside actions', (tester) async {
    await pumpThemed(
      tester,
      SizedBox(
        width: 220,
        child: ScreenHeader(
          title: 'An extremely long screen title that cannot fit',
          actions: [
            BloopIconButton(
              icon: Icons.search,
              tooltip: 'Search',
              onPressed: () {},
            ),
            BloopIconButton(
              icon: Icons.settings,
              tooltip: 'Settings',
              onPressed: () {},
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
