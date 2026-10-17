import 'package:bloop/ui/theme/tokens.dart';
import 'package:bloop/ui/widgets/choice_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_app.dart';

void main() {
  BoxDecoration decorationOf(WidgetTester tester) {
    final ink = tester.widget<Ink>(
      find.descendant(
        of: find.byType(BloopChoiceChip),
        matching: find.byType(Ink),
      ),
    );
    return ink.decoration! as BoxDecoration;
  }

  testWidgets('unselected chip is outlined with no tick', (tester) async {
    await pumpThemed(
      tester,
      BloopChoiceChip(label: 'Work', selected: false, onSelected: (_) {}),
    );

    final decoration = decorationOf(tester);
    expect(decoration.color, Colors.transparent);
    expect((decoration.border! as Border).top.width, 1);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('selected chip is filled, ticked and has a heavier outline', (
    tester,
  ) async {
    await pumpThemed(
      tester,
      BloopChoiceChip(label: 'Work', selected: true, onSelected: (_) {}),
    );

    final decoration = decorationOf(tester);
    expect(decoration.color, BloopTokens.light.action);
    expect((decoration.border! as Border).top.width, 2);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('tapping reports the toggled value', (tester) async {
    final values = <bool>[];
    await pumpThemed(
      tester,
      BloopChoiceChip(label: 'Work', selected: false, onSelected: values.add),
    );

    await tester.tap(find.text('Work'));
    expect(values, [true]);
  });

  testWidgets('tapping a selected chip reports deselection', (tester) async {
    final values = <bool>[];
    await pumpThemed(
      tester,
      BloopChoiceChip(label: 'Work', selected: true, onSelected: values.add),
    );

    await tester.tap(find.text('Work'));
    expect(values, [false]);
  });

  testWidgets('hit area is at least the touch target', (tester) async {
    await pumpThemed(
      tester,
      BloopChoiceChip(label: 'Work', selected: false, onSelected: (_) {}),
    );

    expect(
      tester.getSize(find.byType(InkWell)).height,
      greaterThanOrEqualTo(kBloopMinTouchTarget),
    );
  });

  testWidgets('null onSelected disables the chip', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpThemed(
      tester,
      const BloopChoiceChip(label: 'Work', selected: false, onSelected: null),
    );

    expect(
      tester.getSemantics(find.byType(BloopChoiceChip)),
      matchesSemantics(
        label: 'Work',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        hasSelectedState: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('selection is exposed to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpThemed(
      tester,
      BloopChoiceChip(label: 'Work', selected: true, onSelected: (_) {}),
    );

    expect(
      tester.getSemantics(find.byType(BloopChoiceChip)),
      matchesSemantics(
        label: 'Work',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('disabled selected chip is not filled, so text stays readable', (
    tester,
  ) async {
    await pumpThemed(
      tester,
      const BloopChoiceChip(label: 'Work', selected: true, onSelected: null),
    );

    expect(decorationOf(tester).color, Colors.transparent);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('does not stretch to fill a bounded-height row', (tester) async {
    await pumpThemed(
      tester,
      SizedBox(
        height: 300,
        child: Row(
          children: [
            BloopChoiceChip(label: 'Work', selected: false, onSelected: (_) {}),
          ],
        ),
      ),
    );

    expect(tester.getSize(find.byType(InkWell)).height, kBloopMinTouchTarget);
  });

  testWidgets('long label ellipsises when width is bounded', (tester) async {
    await pumpThemed(
      tester,
      SizedBox(
        width: 100,
        child: BloopChoiceChip(
          label: 'A really quite long filter name',
          selected: true,
          onSelected: (_) {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out in an unbounded-width row', (tester) async {
    await pumpThemed(
      tester,
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            BloopChoiceChip(label: 'Work', selected: true, onSelected: (_) {}),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
