import 'package:bloop/ui/theme/tokens.dart';
import 'package:bloop/ui/widgets/tag_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_app.dart';

void main() {
  testWidgets('shows a hash prefix by default', (tester) async {
    await pumpThemed(tester, const TagPill(label: 'work'));

    expect(find.text('#'), findsOneWidget);
    expect(find.text('work'), findsOneWidget);
  });

  testWidgets('dot marker replaces the hash', (tester) async {
    await pumpThemed(
      tester,
      const TagPill(label: 'home', marker: TagPillMarker.dot),
    );

    expect(find.text('#'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('is outlined and uses no hue', (tester) async {
    await pumpThemed(tester, const TagPill(label: 'work'));

    final box = tester.widget<Container>(
      find.descendant(
        of: find.byType(TagPill),
        matching: find.byType(Container),
      ),
    );
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, isNull);
    expect((decoration.border! as Border).top.color, BloopTokens.light.border);
  });

  testWidgets('long labels ellipsise instead of overflowing', (tester) async {
    await pumpThemed(
      tester,
      const SizedBox(width: 80, child: TagPill(label: 'a very long tag name')),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('read-only pill has no semantics button', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpThemed(tester, const TagPill(label: 'work'));

    expect(
      tester.getSemantics(find.byType(TagPill)),
      isNot(matchesSemantics(isButton: true)),
    );
    handle.dispose();
  });

  testWidgets('tappable pill grows to the touch target and fires onTap', (
    tester,
  ) async {
    var taps = 0;
    await pumpThemed(tester, TagPill(label: 'work', onTap: () => taps++));

    final size = tester.getSize(find.byType(InkWell));
    expect(size.height, greaterThanOrEqualTo(kBloopMinTouchTarget));
    expect(size.width, greaterThanOrEqualTo(kBloopMinTouchTarget));

    await tester.tap(find.byType(TagPill));
    expect(taps, 1);
  });

  testWidgets('tappable pill is announced as a button', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpThemed(tester, TagPill(label: 'work', onTap: () {}));

    expect(
      tester.getSemantics(find.byType(TagPill)),
      matchesSemantics(label: 'work', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('does not stretch to fill a bounded-height row', (tester) async {
    await pumpThemed(
      tester,
      SizedBox(
        height: 300,
        child: Row(
          children: [TagPill(label: 'work', onTap: () {})],
        ),
      ),
    );

    expect(tester.getSize(find.byType(InkWell)).height, kBloopMinTouchTarget);
  });

  testWidgets('lays out in an unbounded-width row', (tester) async {
    await pumpThemed(
      tester,
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: const [TagPill(label: 'work')]),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('work'), findsOneWidget);
  });
}
