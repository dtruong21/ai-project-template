/// Design tokens — Warm Playful
///
/// Soft pastel palette, rounded corners, gentle spring motion. Built for
/// consumer / wellness / habit / journaling apps where warmth and
/// approachability matter more than density. Cross-platform safe
/// (iOS / Android / web).
///
/// Single source of truth. Widgets read from here — no magic values.
///
/// Note on spring motion in Flutter: prefer either Flutter's built-in
/// `SpringSimulation` (via `SpringDescription`) driving an `AnimationController`,
/// or `flutter_animate`'s spring effect. The `damping`, `stiffness`, and `mass`
/// constants below feed directly into `SpringDescription(...)`. For one-off
/// implicit animations, use the `easing` curve (`Curves.easeOutBack`-ish)
/// with a duration from `WarmPlayfulMotion`.
library;

import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';

/// All raw tokens for the Warm Playful design system.
///
/// Colors are split into [WarmPlayfulColorsLight] and [WarmPlayfulColorsDark].
/// Theming code in `theme.dart` consumes these to produce a Material 3
/// [ThemeData].
abstract final class WarmPlayfulTokens {
  static const Color seed = WarmPlayfulColorsLight.accent;
}

// ---------------------------------------------------------------------------
// COLORS
// ---------------------------------------------------------------------------

/// Light palette — cream surfaces, warm brown text, never pure white/black.
abstract final class WarmPlayfulColorsLight {
  static const Color bg = Color(0xFFFFFAF3); // cream — never pure white
  static const Color surface = Color(0xFFFFF1E6); // warm peach surface
  static const Color border = Color(0xFFF0E2D2);
  static const Color divider = Color(0xFFF7EBDD);
  static const Color text = Color(0xFF3D2E1F); // warm dark brown, not black
  static const Color muted = Color(0xFF8C7563);
  static const Color subtle = Color(0xFFB5A18C);
  static const Color accent = Color(0xFFFF8C7A); // warm coral
  static const Color success = Color(0xFF7DBA8A); // sage green
  static const Color danger = Color(0xFFE07A5F); // terracotta
  static const Color warning = Color(0xFFF2CC8F); // butter yellow

  // 5-color category palette — peach, sage, butter, lavender, sky.
  static const Color palettePeach = Color(0xFFFBC4AB);
  static const Color paletteSage = Color(0xFFB5C9A1);
  static const Color paletteButter = Color(0xFFFFE7A0);
  static const Color paletteLavender = Color(0xFFD6CDEA);
  static const Color paletteSky = Color(0xFFB8DCE5);
}

/// Dark palette — warm-toned dark surfaces, warm cream text.
abstract final class WarmPlayfulColorsDark {
  static const Color bg = Color(0xFF231811); // warm-toned dark, not gray
  static const Color surface = Color(0xFF2E211A);
  static const Color border = Color(0xFF3F2F25);
  static const Color divider = Color(0xFF352720);
  static const Color text = Color(0xFFFAEBD7);
  static const Color muted = Color(0xFFB5A18C);
  static const Color subtle = Color(0xFF8C7563);
  static const Color accent = Color(0xFFFF9F8C);
  static const Color success = Color(0xFF9ED1A8);
  static const Color danger = Color(0xFFF09781);
  static const Color warning = Color(0xFFF2D9A1);

  // 5-color category palette — darker, desaturated for dark mode.
  static const Color palettePeach = Color(0xFFE89E84);
  static const Color paletteSage = Color(0xFF94AC81);
  static const Color paletteButter = Color(0xFFE0C880);
  static const Color paletteLavender = Color(0xFFB5ABD0);
  static const Color paletteSky = Color(0xFF92BCC7);
}

// ---------------------------------------------------------------------------
// TYPOGRAPHY
// ---------------------------------------------------------------------------

/// Font families. `body` and `display` use the same family (Nunito); the
/// difference is weight. Mono is rarely needed in this system.
abstract final class WarmPlayfulFonts {
  static const String body = 'Nunito'; // rounded sans — friendly, readable
  static const String display = 'Nunito'; // same family, heavier weights
  static const String mono = 'JetBrainsMono';
}

/// Type scale. Sizes/heights paired with weights tuned for Nunito.
/// Nunito at 400 reads slightly anemic at body size; 500 sits perfectly.
abstract final class WarmPlayfulType {
  // (size, height, weight)
  static const double displaySize = 32;
  static const double displayHeight = 42 / 32;
  static const FontWeight displayWeight = FontWeight.w800;

  static const double h1Size = 24;
  static const double h1Height = 32 / 24;
  static const FontWeight h1Weight = FontWeight.w700;

  static const double h2Size = 18;
  static const double h2Height = 26 / 18;
  static const FontWeight h2Weight = FontWeight.w700;

  static const double bodySize = 16;
  static const double bodyHeight = 26 / 16;
  static const FontWeight bodyWeight = FontWeight.w500;

  static const double captionSize = 13;
  static const double captionHeight = 19 / 13;
  static const FontWeight captionWeight = FontWeight.w500;

  static const double monoMdSize = 14;
  static const double monoMdHeight = 20 / 14;
  static const FontWeight monoMdWeight = FontWeight.w500;
}

// ---------------------------------------------------------------------------
// SPACING
// ---------------------------------------------------------------------------

/// Spacing scale — `0, 4, 8, 12, 16, 24, 32, 48, 64`. Same shape as Notion,
/// but with rounder neighbors.
abstract final class WarmPlayfulSpacing {
  static const double s0 = 0;
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 24;
  static const double s6 = 32;
  static const double s7 = 48;
  static const double s8 = 64;

  static const List<double> scale = <double>[
    s0,
    s1,
    s2,
    s3,
    s4,
    s5,
    s6,
    s7,
    s8,
  ];
}

// ---------------------------------------------------------------------------
// RADIUS — the signature of this system
// ---------------------------------------------------------------------------

/// Significantly more rounded than the other systems — this is the signature.
/// Every container should have a radius. Square corners look hostile here.
abstract final class WarmPlayfulRadius {
  static const double sm = 12; // inputs, small chips
  static const double md = 16; // buttons, list rows
  static const double lg = 24; // cards, modals
  static const double xl = 32; // hero cards, primary-action sheets
  static const double pill = 999; // avatars, pills
}

// ---------------------------------------------------------------------------
// MOTION — spring physics with gentle overshoot
// ---------------------------------------------------------------------------

/// Motion durations + spring parameters.
///
/// Flutter has no first-class `withSpring` like Reanimated. Two recipes:
///
/// 1. **Built-in spring** — drive an [AnimationController] with a
///    [SpringSimulation] constructed from:
///    ```dart
///    final spring = SpringDescription(
///      mass: WarmPlayfulMotion.springMass,
///      stiffness: WarmPlayfulMotion.springStiffness,
///      damping: WarmPlayfulMotion.springDamping,
///    );
///    controller.animateWith(SpringSimulation(spring, 0, 1, 0));
///    ```
///
/// 2. **flutter_animate** — use the spring effect with the same params, e.g.
///    `.scale(...).animate().scale(begin: ..., curve: WarmPlayfulMotion.easing)`.
///
/// For most implicit animations (`AnimatedContainer`, `AnimatedOpacity`),
/// pair [normal] with [easing] — `Curves.easeOutBack` approximates the gentle
/// back-out feel without needing a full simulation.
abstract final class WarmPlayfulMotion {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 500);

  // SpringDescription params — gentle, never aggressive.
  static const double springDamping = 14;
  static const double springStiffness = 180;
  static const double springMass = 1;

  /// Cubic-bezier(0.34, 1.56, 0.64, 1) — gentle back-out. Use for implicit
  /// animations where a full spring simulation is overkill.
  static const Curve easing = Cubic(0.34, 1.56, 0.64, 1);
}
