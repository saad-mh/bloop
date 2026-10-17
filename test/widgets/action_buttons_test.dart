import 'package:bloop/ui/theme/tokens.dart';
import 'package:bloop/ui/widgets/action_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_app.dart';

void main() {
  group('PrimaryButton', () {
    testWidgets('renders a filled button and fires onPressed', (tester) async {
      var taps = 0;
      await pumpThemed(
        tester,
        PrimaryButton(label: 'Save', onPressed: () => taps++),
      );

      expect(find.byType(FilledButton), findsOneWidget);
      await tester.tap(find.text('Save'));
      expect(taps, 1);
    });

    testWidgets('meets the minimum touch target', (tester) async {
      await pumpThemed(tester, PrimaryButton(label: 'Save', onPressed: () {}));

      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(kBloopMinTouchTarget),
      );
    });

    testWidgets('shows the icon when given', (tester) async {
      await pumpThemed(
        tester,
        PrimaryButton(label: 'Save', icon: Icons.check, onPressed: () {}),
      );

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('expand fills the available width', (tester) async {
      await pumpThemed(
        tester,
        SizedBox(
          width: 300,
          child: PrimaryButton(label: 'Save', expand: true, onPressed: () {}),
        ),
      );

      expect(tester.getSize(find.byType(FilledButton)).width, 300);
    });

    testWidgets('null onPressed disables it', (tester) async {
      await pumpThemed(
        tester,
        const PrimaryButton(label: 'Save', onPressed: null),
      );

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });
  });

  group('OutlineActionButton', () {
    testWidgets('renders an outlined button and fires onPressed', (
      tester,
    ) async {
      var taps = 0;
      await pumpThemed(
        tester,
        OutlineActionButton(label: 'Cancel', onPressed: () => taps++),
      );

      expect(find.byType(OutlinedButton), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      expect(taps, 1);
    });

    testWidgets('meets the minimum touch target', (tester) async {
      await pumpThemed(
        tester,
        OutlineActionButton(label: 'Cancel', onPressed: () {}),
      );

      expect(
        tester.getSize(find.byType(OutlinedButton)).height,
        greaterThanOrEqualTo(kBloopMinTouchTarget),
      );
    });

    testWidgets('shows the icon and expands when asked', (tester) async {
      await pumpThemed(
        tester,
        SizedBox(
          width: 300,
          child: OutlineActionButton(
            label: 'Cancel',
            icon: Icons.close,
            expand: true,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(tester.getSize(find.byType(OutlinedButton)).width, 300);
    });
  });
}
