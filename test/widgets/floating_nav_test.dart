import 'package:bloop/ui/theme/app_theme.dart';
import 'package:bloop/ui/theme/tokens.dart';
import 'package:bloop/ui/widgets/floating_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _destinations = [
  FloatingNavDestination(icon: Icons.check_circle_outline, label: 'Tasks'),
  FloatingNavDestination(icon: Icons.adjust, label: 'Focus'),
];

Widget _app({
  int selected = 0,
  ValueChanged<int>? onSelected,
  VoidCallback? onNewTask,
  bool dark = false,
  Widget body = const SizedBox.expand(),
  EdgeInsets viewPadding = EdgeInsets.zero,
}) {
  return MaterialApp(
    theme: dark ? AppTheme.dark : AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(viewPadding: viewPadding),
      child: child!,
    ),
    home: Scaffold(
      body: FloatingNavLayer(
        nav: FloatingNav(
          destinations: _destinations,
          selectedIndex: selected,
          onSelected: onSelected ?? (_) {},
          onNewTask: onNewTask ?? () {},
        ),
        child: body,
      ),
    ),
  );
}

void main() {
  group('FloatingNav', () {
    testWidgets('shows only the given destinations and a New task button', (
      tester,
    ) async {
      await tester.pumpWidget(_app());

      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Focus'), findsOneWidget);
      expect(find.text('Completed'), findsNothing);
      expect(find.byTooltip('New task'), findsOneWidget);
    });

    testWidgets('reports the tapped destination', (tester) async {
      final taps = <int>[];
      await tester.pumpWidget(_app(onSelected: taps.add));

      await tester.tap(find.text('Focus'));
      await tester.tap(find.text('Tasks'));

      expect(taps, [1, 0]);
    });

    testWidgets('New task fires its own callback, not a tab change', (
      tester,
    ) async {
      final tabs = <int>[];
      var newTasks = 0;
      await tester.pumpWidget(
        _app(onSelected: tabs.add, onNewTask: () => newTasks++),
      );

      await tester.tap(find.byTooltip('New task'));

      expect(newTasks, 1);
      expect(tabs, isEmpty);
    });

    testWidgets('marks only the selected destination as selected', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(selected: 1));

      expect(
        tester.getSemantics(find.text('Focus')),
        containsSemantics(label: 'Focus', isButton: true, isSelected: true),
      );
      expect(
        tester.getSemantics(find.text('Tasks')),
        isNot(containsSemantics(isSelected: true)),
      );
      semantics.dispose();
    });

    testWidgets('fills the selected segment with the action colour', (
      tester,
    ) async {
      await tester.pumpWidget(_app(selected: 0));
      await tester.pumpAndSettle();

      final segment = tester.widget<AnimatedContainer>(
        find.ancestor(
          of: find.text('Tasks'),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final fill = (segment.decoration! as ShapeDecoration).color;
      expect(fill, BloopTokens.light.action);
    });

    testWidgets('destinations and New task meet the touch target', (
      tester,
    ) async {
      await tester.pumpWidget(_app());

      for (final label in ['Tasks', 'Focus']) {
        final size = tester.getSize(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(AnimatedContainer),
          ),
        );
        expect(size.height, greaterThanOrEqualTo(kBloopMinTouchTarget));
        expect(size.width, greaterThanOrEqualTo(kBloopMinTouchTarget));
      }
      final add = tester.getSize(find.byType(IconButton));
      expect(add.shortestSide, greaterThanOrEqualTo(kBloopMinTouchTarget));
    });

    testWidgets('fits a narrow screen at a large text scale', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: _app(),
        ),
      );

      expect(tester.takeException(), isNull);
      final nav = tester.getRect(find.byType(FloatingNav));
      expect(nav.left, greaterThanOrEqualTo(0));
      expect(nav.right, lessThanOrEqualTo(320));
      expect(find.byTooltip('New task'), findsOneWidget);
    });

    testWidgets('renders in the dark theme', (tester) async {
      await tester.pumpWidget(_app(dark: true));

      expect(find.text('Tasks'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('FloatingNavLayer', () {
    testWidgets('centres the pill and button as one group', (tester) async {
      await tester.pumpWidget(_app());

      final pill = tester.getRect(find.byType(FloatingNav));
      final screen = tester.getRect(find.byType(Scaffold));
      expect(pill.center.dx, closeTo(screen.center.dx, 0.5));
    });

    testWidgets('sits above the bottom inset', (tester) async {
      await tester.pumpWidget(
        _app(viewPadding: const EdgeInsets.only(bottom: 34)),
      );

      final nav = tester.getRect(find.byType(FloatingNav));
      final screen = tester.getRect(find.byType(Scaffold));
      expect(screen.bottom - nav.bottom, kFloatingNavBottomMargin + 34);
    });

    testWidgets('lets taps through the scrim to the content', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(
          body: Align(
            alignment: Alignment.bottomLeft,
            child: SizedBox(
              height: 40,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const Text('under scrim'),
              ),
            ),
          ),
        ),
      );

      // Bottom-left sits under the scrim but clear of the centred nav.
      await tester.tap(find.text('under scrim'));
      expect(taps, 1);
    });

    testWidgets('clearance covers nav, margin and the system inset', (
      tester,
    ) async {
      late double clearance;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(viewPadding: const EdgeInsets.only(bottom: 20)),
            child: child!,
          ),
          home: Builder(
            builder: (context) {
              clearance = floatingNavClearance(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(
        clearance,
        greaterThanOrEqualTo(
          kFloatingNavHeight + kFloatingNavBottomMargin + 20,
        ),
      );
    });
  });
}
