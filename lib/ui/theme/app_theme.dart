import 'package:flutter/material.dart';

import 'tokens.dart';

/// Hand-built monochrome themes. No seed colour, no accent hues.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light, BloopTokens.light);
  static ThemeData get dark => _build(Brightness.dark, BloopTokens.dark);

  static ThemeData _build(Brightness brightness, BloopTokens t) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: t.action,
      onPrimary: t.onAction,
      secondary: t.action,
      onSecondary: t.onAction,
      tertiary: t.muted,
      onTertiary: t.surface,
      error: t.error,
      onError: t.onError,
      surface: t.surface,
      onSurface: t.ink,
      onSurfaceVariant: t.muted,
      surfaceDim: t.sunken,
      surfaceBright: t.raised,
      surfaceContainerLowest: t.raised,
      surfaceContainerLow: t.surface,
      surfaceContainer: t.sunken,
      surfaceContainerHigh: t.sunken,
      surfaceContainerHighest: t.sunken,
      outline: t.muted,
      outlineVariant: t.border,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: t.ink,
      onInverseSurface: t.surface,
      inversePrimary: t.onAction,
      primaryContainer: t.sunken,
      onPrimaryContainer: t.ink,
      secondaryContainer: t.sunken,
      onSecondaryContainer: t.ink,
      tertiaryContainer: t.sunken,
      onTertiaryContainer: t.ink,
      errorContainer: t.sunken,
      onErrorContainer: t.error,
      surfaceTint: Colors.transparent,
    );

    final textTheme = _textTheme(t);
    final smallShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(BloopRadii.md),
    );
    const minSize = Size(kBloopMinTouchTarget, kBloopMinTouchTarget);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.surface,
      canvasColor: t.surface,
      cardColor: t.raised,
      dividerColor: t.border,
      fontFamily: BloopFonts.text,
      textTheme: textTheme,
      extensions: [t],
      splashFactory: InkRipple.splashFactory,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      dividerTheme: DividerThemeData(color: t.border, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: t.ink),
      appBarTheme: AppBarTheme(
        backgroundColor: t.surface,
        foregroundColor: t.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: t.raised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BloopRadii.lg),
          side: BorderSide(color: t.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.action,
          foregroundColor: t.onAction,
          disabledBackgroundColor: t.sunken,
          disabledForegroundColor: t.muted,
          minimumSize: minSize,
          padding: const EdgeInsets.symmetric(horizontal: BloopSpace.x6),
          shape: smallShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.action,
          foregroundColor: t.onAction,
          disabledBackgroundColor: t.sunken,
          disabledForegroundColor: t.muted,
          elevation: 0,
          minimumSize: minSize,
          padding: const EdgeInsets.symmetric(horizontal: BloopSpace.x6),
          shape: smallShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.ink,
          disabledForegroundColor: t.muted,
          minimumSize: minSize,
          padding: const EdgeInsets.symmetric(horizontal: BloopSpace.x6),
          side: BorderSide(color: t.border),
          shape: smallShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.ink,
          disabledForegroundColor: t.muted,
          minimumSize: minSize,
          padding: const EdgeInsets.symmetric(horizontal: BloopSpace.x4),
          shape: smallShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: t.ink,
          disabledForegroundColor: t.muted,
          minimumSize: minSize,
          shape: smallShape,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.action,
        foregroundColor: t.onAction,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BloopRadii.lg),
        ),
      ),
      // Underline title field; the other fields reuse the same look.
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(vertical: BloopSpace.x3),
        hintStyle: textTheme.bodyLarge?.copyWith(color: t.muted),
        labelStyle: textTheme.bodyMedium?.copyWith(color: t.muted),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(color: t.muted),
        border: UnderlineInputBorder(borderSide: BorderSide(color: t.border)),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: t.border),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: t.ink, width: 2),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: t.error),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: t.error, width: 2),
        ),
        errorStyle: textTheme.bodySmall?.copyWith(color: t.error),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.sunken,
        selectedColor: t.action,
        disabledColor: t.sunken,
        labelStyle: textTheme.labelMedium?.copyWith(color: t.ink),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: t.onAction),
        checkmarkColor: t.onAction,
        iconTheme: IconThemeData(color: t.muted, size: 16),
        side: BorderSide(color: t.border),
        elevation: 0,
        pressElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BloopRadii.sm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: BloopSpace.x2),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.raised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BloopRadii.lg),
          side: BorderSide(color: t.border),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.raised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalBackgroundColor: t.raised,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(BloopRadii.lg),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.action,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: t.onAction),
        actionTextColor: t.onAction,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BloopRadii.md),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.onAction : t.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.action : t.sunken,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.action : t.border,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? t.action : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(t.onAction),
        side: BorderSide(color: t.muted, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BloopRadii.sm),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: t.ink,
        textColor: t.ink,
        minVerticalPadding: BloopSpace.x2,
        minTileHeight: kBloopMinTouchTarget,
        contentPadding: const EdgeInsets.symmetric(horizontal: BloopSpace.x4),
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall?.copyWith(color: t.muted),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.action,
        linearTrackColor: t.sunken,
        circularTrackColor: t.sunken,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: t.action,
        inactiveTrackColor: t.sunken,
        thumbColor: t.action,
        overlayColor: t.action.withValues(alpha: 0.12),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.raised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BloopRadii.md),
          side: BorderSide(color: t.border),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: t.ink,
        selectionColor: t.ink.withValues(alpha: 0.2),
        selectionHandleColor: t.ink,
      ),
    );
  }

  /// Fraunces for display, headline and `titleLarge`; Work Sans for the rest.
  static TextTheme _textTheme(BloopTokens t) {
    TextStyle heading(double size, FontWeight weight, double height) =>
        TextStyle(
          fontFamily: BloopFonts.heading,
          fontSize: size,
          fontWeight: weight,
          height: height / size,
          color: t.ink,
        );
    TextStyle text(
      double size,
      FontWeight weight,
      double height, {
      double letterSpacing = 0,
    }) => TextStyle(
      fontFamily: BloopFonts.text,
      fontSize: size,
      fontWeight: weight,
      height: height / size,
      letterSpacing: letterSpacing,
      color: t.ink,
    );

    return TextTheme(
      displayLarge: heading(48, FontWeight.w600, 56),
      displayMedium: heading(40, FontWeight.w600, 48),
      displaySmall: heading(32, FontWeight.w600, 40),
      headlineLarge: heading(28, FontWeight.w600, 36),
      headlineMedium: heading(24, FontWeight.w600, 32),
      headlineSmall: heading(20, FontWeight.w600, 28),
      titleLarge: heading(20, FontWeight.w600, 28),
      titleMedium: text(16, FontWeight.w600, 24, letterSpacing: 0.1),
      titleSmall: text(14, FontWeight.w600, 20, letterSpacing: 0.1),
      bodyLarge: text(16, FontWeight.w400, 24, letterSpacing: 0.2),
      bodyMedium: text(14, FontWeight.w400, 20, letterSpacing: 0.2),
      bodySmall: text(12, FontWeight.w400, 16, letterSpacing: 0.3),
      labelLarge: text(14, FontWeight.w600, 20, letterSpacing: 0.2),
      labelMedium: text(12, FontWeight.w600, 16, letterSpacing: 0.4),
      labelSmall: text(11, FontWeight.w600, 16, letterSpacing: 0.4),
    );
  }
}
