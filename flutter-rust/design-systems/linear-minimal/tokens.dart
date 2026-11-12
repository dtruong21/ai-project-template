// Design tokens — Linear / Vercel minimal
//
// High-contrast monochrome. Sharp typography. Generous negative space.
// Built for modern SaaS tools where the product is the focus and the chrome
// gets out of the way.
//
// Single source of truth. Components import from here — no magic values.
// Mirrors the RN sibling at design-systems/linear-minimal/tokens.ts.

import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';

/// Surface, text, accent, and semantic colors for light and dark.
/// Use [AppColors.light] / [AppColors.dark] inside `theme.dart` — features
/// should read colors via `Theme.of(context).colorScheme` or the
/// [AppPalette] ThemeExtension, never these raw values directly.
abstract final class AppColors {
  const AppColors._();

  static const light = _Palette(
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFFAFAFA),
    border: Color(0xFFEAEAEA),
    divider: Color(0xFFF0F0F0),
    text: Color(0xFF0A0A0A), // near-pure black
    muted: Color(0xFF666666),
    subtle: Color(0xFF999999),
    accent: Color(0xFF5E6AD2), // Linear's purple-blue
    success: Color(0xFF0A9956),
    danger: Color(0xFFE5484D),
    warning: Color(0xFFEE9D2B),
  );

  static const dark = _Palette(
    bg: Color(0xFF0A0A0A), // near-pure black
    surface: Color(0xFF141414),
    border: Color(0xFF2A2A2A),
    divider: Color(0xFF1F1F1F),
    text: Color(0xFFFAFAFA),
    muted: Color(0xFF999999),
    subtle: Color(0xFF666666),
    accent: Color(0xFF8D95F2), // accessible on dark
    success: Color(0xFF3DD68C),
    danger: Color(0xFFFF6369),
    warning: Color(0xFFFFB648),
  );

  /// Seed used by `ColorScheme.fromSeed` in `theme.dart`.
  static const Color seed = Color(0xFF5E6AD2);
}

class _Palette {
  const _Palette({
    required this.bg,
    required this.surface,
    required this.border,
    required this.divider,
    required this.text,
    required this.muted,
    required this.subtle,
    required this.accent,
    required this.success,
    required this.danger,
    required this.warning,
  });

  final Color bg;
  final Color surface;
  final Color border;
  final Color divider;
  final Color text;
  final Color muted;
  final Color subtle;
  final Color accent;
  final Color success;
  final Color danger;
  final Color warning;
}

/// Type ramp — Linear's tight density. Body is 15, not 16.
/// Letter-spacing tightens on display + h1 — the signature look.
abstract final class AppTypography {
  const AppTypography._();

  /// Resolved at runtime by `google_fonts` in `theme.dart`.
  static const String bodyFamily = 'Inter';
  static const String monoFamily = 'JetBrainsMono';

  // size / height / weight / tracking
  static const display = TextStyle(
    fontSize: 40,
    height: 44 / 40,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  static const h1 = TextStyle(
    fontSize: 28,
    height: 32 / 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );

  static const h2 = TextStyle(
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15,
  );

  static const body = TextStyle(
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w400,
  );

  static const caption = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
  );

  static const monoMd = TextStyle(
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w500,
  );
}

/// Spacing scale — tighter than Notion's. 4/8/12/16/20/24/32/40/48/64/96.
/// The extra 20 and 40 let you tune density when 16/24/32 feel too coarse.
abstract final class AppSpacing {
  const AppSpacing._();

  static const double s0 = 0;
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s10 = 40;
  static const double s12 = 48;
  static const double s16 = 64;
  static const double s24 = 96;

  static const List<double> scale = [
    s0,
    s1,
    s2,
    s3,
    s4,
    s5,
    s6,
    s8,
    s10,
    s12,
    s16,
    s24,
  ];
}

/// Sharper radius than Notion's. Stay under 8 — anything rounder breaks
/// the aesthetic.
abstract final class AppRadius {
  const AppRadius._();

  static const double sm = 4;
  static const double md = 6; // default
  static const double lg = 8;
  static const double pill = 999;
}

/// Motion — Linear's signature crispness. Snappy, eased, never bouncy.
/// Use [AppMotion.curve] everywhere you'd reach for [Curves.easeOutCubic]
/// to get Linear's exact bezier.
abstract final class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 100);
  static const Duration normal = Duration(milliseconds: 150);
  static const Duration slow = Duration(milliseconds: 250);

  /// Linear's curve: cubic-bezier(0.32, 0.72, 0, 1).
  /// Mirrors the CSS easing used on linear.app.
  static const Cubic curve = Cubic(0.32, 0.72, 0, 1);
}

/// Aggregated tokens — convenience re-export so a feature can
/// `import 'tokens.dart' as t;` and reach everything in one place.
abstract final class AppTokens {
  const AppTokens._();

  static const Color seed = AppColors.seed;
}
