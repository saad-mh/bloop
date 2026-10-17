import 'package:bloop/ui/theme/app_theme.dart';
import 'package:bloop/ui/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

bool _isGray(Color c) => (c.r - c.g).abs() < 0.02 && (c.g - c.b).abs() < 0.02;

void main() {
  group('AppTheme', () {
    test('light and dark use their token palettes', () {
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(AppTheme.light.scaffoldBackgroundColor, BloopTokens.light.surface);
      expect(AppTheme.dark.scaffoldBackgroundColor, BloopTokens.dark.surface);
      expect(AppTheme.light.colorScheme.primary, BloopTokens.light.action);
      expect(AppTheme.dark.colorScheme.primary, BloopTokens.dark.action);
      expect(AppTheme.light.extension<BloopTokens>(), BloopTokens.light);
    });

    test('has no accent hues; error red only on error roles', () {
      for (final t in [BloopTokens.light, BloopTokens.dark]) {
        for (final c in [
          t.raised,
          t.sunken,
          t.border,
          t.ink,
          t.muted,
          t.action,
          t.onAction,
        ]) {
          // Warm off-white surface is the one allowed tint.
          expect((c.r - c.b).abs(), lessThan(0.04));
        }
        expect(_isGray(t.sunken), isTrue);
        expect(_isGray(t.border), isTrue);
      }
      final scheme = AppTheme.light.colorScheme;
      expect(scheme.error, BloopTokens.light.error);
      expect(scheme.primary, isNot(scheme.error));
    });

    test('bundled fonts are wired to the text theme', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        expect(theme.textTheme.headlineMedium?.fontFamily, BloopFonts.heading);
        expect(theme.textTheme.bodyMedium?.fontFamily, BloopFonts.text);
      }
    });

    test('buttons meet the 48dp touch target', () {
      final size = AppTheme.light.filledButtonTheme.style!.minimumSize!.resolve(
        const {},
      );
      expect(size!.height, greaterThanOrEqualTo(kBloopMinTouchTarget));
    });

    testWidgets('renders in both modes', (tester) async {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: mode,
            home: Scaffold(
              body: Column(
                children: [
                  FilledButton(onPressed: () {}, child: const Text('Go')),
                  const TextField(
                    decoration: InputDecoration(hintText: 'Title'),
                  ),
                  Switch(value: true, onChanged: (_) {}),
                  const Chip(label: Text('tag')),
                ],
              ),
            ),
          ),
        );
        expect(find.text('Go'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
