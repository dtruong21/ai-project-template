/// The token contract between a design system and the component kit.
///
/// Each design system's `theme.dart` registers one [UiTokens] in
/// `ThemeData.extensions`. Components in `lib/core/ui/` read ONLY
/// `Theme.of(context)` (color scheme, text theme) and [UiTokens] — never a
/// design system's own token classes — so switching systems restyles every
/// component without touching one.
library;

import 'package:flutter/material.dart';

/// Spacing is the same 4-pt grid in every design system, so it is a constant
/// rather than a themed value.
abstract final class Gap {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Minimum touch target (Material and Apple HIG both land on 44–48).
  static const double touchTarget = 48;
}

@immutable
class UiTokens extends ThemeExtension<UiTokens> {
  const UiTokens({
    required this.success,
    required this.warning,
    required this.danger,
    required this.muted,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.motionFast,
    required this.motionNormal,
    required this.motionSlow,
    required this.motionCurve,
  });

  /// Sensible values derived from a plain Material theme. Used when a theme
  /// forgot to register [UiTokens] — components degrade instead of crashing.
  factory UiTokens.fallback(ColorScheme scheme) => UiTokens(
    success: const Color(0xFF2E7D32),
    warning: const Color(0xFFB26A00),
    danger: scheme.error,
    muted: scheme.onSurfaceVariant,
    radiusSm: 4,
    radiusMd: 8,
    radiusLg: 12,
    motionFast: const Duration(milliseconds: 120),
    motionNormal: const Duration(milliseconds: 200),
    motionSlow: const Duration(milliseconds: 300),
    motionCurve: Curves.easeOut,
  );

  static UiTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<UiTokens>() ?? UiTokens.fallback(theme.colorScheme);
  }

  /// Positive outcome (saved, synced). Not for decoration.
  final Color success;

  /// Needs attention but is not blocking.
  final Color warning;

  /// Destructive actions and blocking errors.
  final Color danger;

  /// Secondary text: captions, helper text, timestamps.
  final Color muted;

  /// Inputs, chips.
  final double radiusSm;

  /// Buttons, list rows.
  final double radiusMd;

  /// Cards, sheets, dialogs.
  final double radiusLg;

  /// Press feedback, toggles.
  final Duration motionFast;

  /// Most transitions.
  final Duration motionNormal;

  /// Large surfaces entering (sheets, page-level changes).
  final Duration motionSlow;

  final Curve motionCurve;

  @override
  UiTokens copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? muted,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    Duration? motionFast,
    Duration? motionNormal,
    Duration? motionSlow,
    Curve? motionCurve,
  }) => UiTokens(
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    muted: muted ?? this.muted,
    radiusSm: radiusSm ?? this.radiusSm,
    radiusMd: radiusMd ?? this.radiusMd,
    radiusLg: radiusLg ?? this.radiusLg,
    motionFast: motionFast ?? this.motionFast,
    motionNormal: motionNormal ?? this.motionNormal,
    motionSlow: motionSlow ?? this.motionSlow,
    motionCurve: motionCurve ?? this.motionCurve,
  );

  @override
  UiTokens lerp(ThemeExtension<UiTokens>? other, double t) {
    if (other is! UiTokens) return this;
    return UiTokens(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      radiusSm: t < 0.5 ? radiusSm : other.radiusSm,
      radiusMd: t < 0.5 ? radiusMd : other.radiusMd,
      radiusLg: t < 0.5 ? radiusLg : other.radiusLg,
      motionFast: t < 0.5 ? motionFast : other.motionFast,
      motionNormal: t < 0.5 ? motionNormal : other.motionNormal,
      motionSlow: t < 0.5 ? motionSlow : other.motionSlow,
      motionCurve: t < 0.5 ? motionCurve : other.motionCurve,
    );
  }
}
