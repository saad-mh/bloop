import 'package:bloop/ui/theme/tokens.dart';
import 'package:bloop/ui/widgets/segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_app.dart';

const _priorities = [
  Segment(value: 'low', label: 'Low'),
  Segment(value: 'normal', label: 'Normal'),
  Segment(value: 'high', label: 'High'),
];

void main() {
  testWidgets('shows every segment', (tester) async {
    await pumpThemed(
      tester,
      SegmentedControl<String>(
        segments: _priorities,
        selected: 'normal',
        onChanged: (_) {},
      ),
    );

    for (final label in ['Low', 'Normal', 'High']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('selected segment is filled and bold', (tester) async {
    await pumpThemed(
      tester,
      SegmentedControl<String>(
        segments: _priorities,
        selected: 'normal',
        onChanged: (_) {},
      ),
    );

    Text label(String s) => tester.widget<Text>(find.text(s));
    expect(label('Normal').style?.fontWeight, FontWeight.w700);
    expect(label('Normal').style?.color, BloopTokens.light.onAction);
    expect(label('Low').style?.fontWeight, FontWeight.w500);
    expect(label('Low').style?.color, BloopTokens.light.ink);

    final fills = tester
        .widgetList<Material>(
          find.descendant(
            of: find.byType(SegmentedControl<String>),
            matching: find.byType(Material),
          ),
        )
        .where((m) => m.color == BloopTokens.light.action);
    expect(fills, hasLength(1));
  });

  testWidgets('tapping a segment reports its value', (tester) async {
    final values = <String>[];
    await pumpThemed(
      tester,
      SegmentedControl<String>(
        segments: _priorities,
        selected: 'normal',
        onChanged: values.add,
      ),
    );

    await tester.tap(find.text('High'));
    expect(values, ['high']);
  });

  testWidgets('works with non-string values (durations + custom)', (
    tester,
  ) async {
    int? picked;
    await pumpThemed(
      tester,
      SegmentedControl<int>(
        segments: const [
          Segment(value: 15, label: '15'),
          Segment(value: 25, label: '25'),
          Segment(value: 45, label: '45'),
          Segment(value: -1, label: 'Custom'),
        ],
        selected: 25,
        onChanged: (v) => picked = v,
      ),
    );

    await tester.tap(find.text('Custom'));
    expect(picked, -1);
  });

  testWidgets('each segment keeps the minimum touch target', (tester) async {
    await pumpThemed(
      tester,
      SegmentedControl<String>(
        segments: _priorities,
        selected: 'low',
        onChanged: (_) {},
      ),
    );

    for (final inkWell in tester.widgetList(find.byType(InkWell))) {
      final size = tester.getSize(find.byWidget(inkWell));
      expect(size.height, greaterThanOrEqualTo(kBloopMinTouchTarget));
    }
  });

  testWidgets('null onChanged disables every segment', (tester) async {
    await pumpThemed(
      tester,
      const SegmentedControl<String>(
        segments: _priorities,
        selected: 'low',
        onChanged: null,
      ),
    );

    for (final inkWell in tester.widgetList<InkWell>(find.byType(InkWell))) {
      expect(inkWell.onTap, isNull);
    }
  });

  testWidgets('segments are exposed as a mutually exclusive group', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpThemed(
      tester,
      SegmentedControl<String>(
        segments: _priorities,
        selected: 'normal',
        onChanged: (_) {},
      ),
    );

    expect(
      tester.getSemantics(find.text('Normal')),
      matchesSemantics(
        label: 'Normal',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasSelectedState: true,
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('narrow width truncates labels without overflow', (tester) async {
    await pumpThemed(
      tester,
      SizedBox(
        width: 200,
        child: SegmentedControl<String>(
          segments: const [
            Segment(value: 'a', label: 'A long label'),
            Segment(value: 'b', label: 'Another long one'),
            Segment(value: 'c', label: 'Third long one'),
          ],
          selected: 'a',
          onChanged: (_) {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled selection is not drawn in the action fill', (
    tester,
  ) async {
    await pumpThemed(
      tester,
      const SegmentedControl<String>(
        segments: _priorities,
        selected: 'normal',
        onChanged: null,
      ),
    );

    final fills = tester
        .widgetList<Material>(
          find.descendant(
            of: find.byType(SegmentedControl<String>),
            matching: find.byType(Material),
          ),
        )
        .where((m) => m.color == BloopTokens.light.action);
    expect(fills, isEmpty);
    expect(
      tester.widget<Text>(find.text('Normal')).style?.color,
      BloopTokens.light.ink,
    );
  });
}
