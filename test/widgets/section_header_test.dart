import 'package:bloop/ui/theme/tokens.dart';
import 'package:bloop/ui/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_app.dart';

void main() {
  testWidgets('shows label, count and date', (tester) async {
    await pumpThemed(
      tester,
      const SectionHeader(label: 'Today', count: 3, date: 'Sat, Oct 17'),
    );

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Sat, Oct 17'), findsOneWidget);
  });

  testWidgets('count is lighter than the label', (tester) async {
    await pumpThemed(tester, const SectionHeader(label: 'Today', count: 3));

    final label = tester.widget<Text>(find.text('Today'));
    final count = tester.widget<Text>(find.text('3'));
    expect(count.style?.color, BloopTokens.light.muted);
    expect(
      count.style!.fontWeight!.value,
      lessThan(label.style!.fontWeight!.value),
    );
  });

  testWidgets('a zero count is still shown', (tester) async {
    await pumpThemed(tester, const SectionHeader(label: 'Overdue', count: 0));

    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('without onToggle there is no chevron or tap target', (
    tester,
  ) async {
    await pumpThemed(tester, const SectionHeader(label: 'Today', count: 3));

    expect(find.byIcon(Icons.expand_more), findsNothing);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('with onToggle it shows a chevron and fires on tap', (
    tester,
  ) async {
    var toggles = 0;
    await pumpThemed(
      tester,
      SectionHeader(label: 'Today', count: 3, onToggle: () => toggles++),
    );

    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    await tester.tap(find.text('Today'));
    expect(toggles, 1);
  });

  testWidgets('chevron turns when collapsed', (tester) async {
    await pumpThemed(
      tester,
      SectionHeader(label: 'Today', expanded: true, onToggle: () {}),
    );
    expect(
      tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns,
      0,
    );

    await pumpThemed(
      tester,
      SectionHeader(label: 'Today', expanded: false, onToggle: () {}),
    );
    expect(
      tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns,
      -0.25,
    );
  });

  testWidgets('collapsible header is a 48dp header button with state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpThemed(
      tester,
      SectionHeader(label: 'Today', count: 3, expanded: false, onToggle: () {}),
    );

    expect(
      tester.getSize(find.byType(InkWell)).height,
      greaterThanOrEqualTo(kBloopMinTouchTarget),
    );
    expect(
      tester.getSemantics(find.byType(SectionHeader)),
      matchesSemantics(
        label: 'Today, 3',
        isHeader: true,
        isButton: true,
        hasExpandedState: true,
        isExpanded: false,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('plain header is announced as a header only', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpThemed(tester, const SectionHeader(label: 'Whenever', count: 2));

    expect(
      tester.getSemantics(find.byType(SectionHeader)),
      matchesSemantics(label: 'Whenever, 2', isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('long label and date do not overflow', (tester) async {
    await pumpThemed(
      tester,
      SizedBox(
        width: 200,
        child: SectionHeader(
          label: 'A very long section label indeed',
          count: 12,
          date: 'Saturday, October 17',
          onToggle: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
