import 'package:flutter/material.dart';

/// Font families bundled under `assets/fonts` (see pubspec.yaml).
abstract final class BloopFonts {
  static const heading = 'Fraunces';
  static const text = 'WorkSans';
}

/// Corner radii: small (chips, inputs), medium (buttons, tiles), large
/// (cards, dialogs, sheets).
abstract final class BloopRadii {
  static const double sm = 4;
  static const double md = 6;
  static const double lg = 12;
}

/// 4px spacing scale.
abstract final class BloopSpace {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x10 = 40;
  static const double x12 = 48;
}

/// Minimum interactive size.
const double kBloopMinTouchTarget = 48;

/// Monochrome palette. Read it with `BloopTokens.of(context)` rather than
/// hard-coding colours in widgets.
@immutable
class BloopTokens extends ThemeExtension<BloopTokens> {
  const BloopTokens({
    required this.surface,
    required this.raised,
    required this.sunken,
    required this.border,
    required this.ink,
    required this.muted,
    required this.action,
    required this.onAction,
    required this.error,
    required this.onError,
  });

  /// Page background.
  final Color surface;

  /// Cards, sheets and dialogs sitting above [surface].
  final Color raised;

  /// Wells and tracks sitting below [surface].
  final Color sunken;
  final Color border;

  /// Primary text and icons.
  final Color ink;

  /// Secondary text and icons.
  final Color muted;

  /// Fill for primary buttons and pills.
  final Color action;
  final Color onAction;

  /// Destructive and error states only.
  final Color error;
  final Color onError;

  static const light = BloopTokens(
    surface: Color(0xFFFAF9F7),
    raised: Color(0xFFFFFFFF),
    sunken: Color(0xFFF1F1F1),
    border: Color(0xFFE0E0E0),
    ink: Color(0xFF1F1F1F),
    muted: Color(0xFF6B6B6B),
    action: Color(0xFF2B2B2B),
    onAction: Color(0xFFFAF9F7),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
  );

  static const dark = BloopTokens(
    surface: Color(0xFF121212),
    raised: Color(0xFF1C1C1C),
    sunken: Color(0xFF0C0C0C),
    border: Color(0xFF2E2E2E),
    ink: Color(0xFFF1F0EE),
    muted: Color(0xFF9A9A9A),
    action: Color(0xFFEDEBE8),
    onAction: Color(0xFF1F1F1F),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
  );

  static BloopTokens of(BuildContext context) =>
      Theme.of(context).extension<BloopTokens>() ?? light;

  @override
  BloopTokens copyWith({
    Color? surface,
    Color? raised,
    Color? sunken,
    Color? border,
    Color? ink,
    Color? muted,
    Color? action,
    Color? onAction,
    Color? error,
    Color? onError,
  }) {
    return BloopTokens(
      surface: surface ?? this.surface,
      raised: raised ?? this.raised,
      sunken: sunken ?? this.sunken,
      border: border ?? this.border,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      action: action ?? this.action,
      onAction: onAction ?? this.onAction,
      error: error ?? this.error,
      onError: onError ?? this.onError,
    );
  }

  @override
  BloopTokens lerp(ThemeExtension<BloopTokens>? other, double t) {
    if (other is! BloopTokens) return this;
    return BloopTokens(
      surface: Color.lerp(surface, other.surface, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      sunken: Color.lerp(sunken, other.sunken, t)!,
      border: Color.lerp(border, other.border, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      action: Color.lerp(action, other.action, t)!,
      onAction: Color.lerp(onAction, other.onAction, t)!,
      error: Color.lerp(error, other.error, t)!,
      onError: Color.lerp(onError, other.onError, t)!,
    );
  }
}
