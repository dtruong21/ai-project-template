/// Design tokens — Notion + GitHub
///
/// Calm document feel + data-dense surfaces. Built for productivity apps where
/// the user spends a lot of time reading and editing. Cross-platform safe
/// (iOS / Android / web).
///
/// Single source of truth. Components import from here — no magic values.
library;

import 'package:flutter/material.dart';

abstract class NotionGithubTokens {
  static const _LightColors light = _LightColors();
  static const _DarkColors dark = _DarkColors();
  static const _Typography typography = _Typography();

  /// Multiples of 4. Index-addressable: [0, 4, 8, 12, 16, 24, 32, 48, 64].
  static const List<double> spacing = <double>[0, 4, 8, 12, 16, 24, 32, 48, 64];

  static const _Radius radius = _Radius();
  static const _Motion motion = _Motion();
}

class _LightColors {
  const _LightColors();

  final Color bg = const Color(0xFFFFFFFF);
  final Color surface = const Color(0xFFF7F6F3); // Notion warm gray
  final Color border = const Color(0xFFE9E9E7);
  final Color divider = const Color(0xFFEDEDEC);
  final Color text = const Color(0xFF37352F); // Notion ink
  final Color muted = const Color(0xFF787774);
  final Color subtle = const Color(0xFF9B9A97);
  final Color accent = const Color(0xFF2383E2); // Notion blue
  final Color success = const Color(0xFF26A641); // GitHub mid-green
  final Color danger = const Color(0xFFF85149);
  final Color warning = const Color(0xFFD29922);

  /// GitHub contribution scale, light theme. 5 steps, low → high.
  final List<Color> heatmap = const <Color>[
    Color(0xFFEBEDF0),
    Color(0xFF9BE9A8),
    Color(0xFF40C463),
    Color(0xFF30A14E),
    Color(0xFF216E39),
  ];
}

class _DarkColors {
  const _DarkColors();

  final Color bg = const Color(0xFF0D1117); // GitHub dark
  final Color surface = const Color(0xFF161B22);
  final Color border = const Color(0xFF30363D);
  final Color divider = const Color(0xFF21262D);
  final Color text = const Color(0xFFE6EDF3); // GitHub fg
  final Color muted = const Color(0xFF7D8590);
  final Color subtle = const Color(0xFF6E7681);
  final Color accent = const Color(0xFF388BFD); // accessible blue on dark
  final Color success = const Color(0xFF3FB950);
  final Color danger = const Color(0xFFF85149);
  final Color warning = const Color(0xFFD29922);

  /// GitHub contribution scale, dark theme. 5 steps, low → high.
  final List<Color> heatmap = const <Color>[
    Color(0xFF161B22),
    Color(0xFF0E4429),
    Color(0xFF006D32),
    Color(0xFF26A641),
    Color(0xFF39D353),
  ];
}

class _Typography {
  const _Typography();

  /// Body face. Inter via google_fonts.
  final String bodyFamily = 'Inter';

  /// Monospace face. JetBrains Mono via google_fonts.
  /// Used for streaks, dates, numbers, code.
  final String monoFamily = 'JetBrains Mono';

  final _TextStyleSpec display = const _TextStyleSpec(
    fontSize: 32,
    height: 40 / 32,
    weight: FontWeight.w600,
  );
  final _TextStyleSpec h1 = const _TextStyleSpec(
    fontSize: 24,
    height: 32 / 24,
    weight: FontWeight.w600,
  );
  final _TextStyleSpec h2 = const _TextStyleSpec(
    fontSize: 18,
    height: 26 / 18,
    weight: FontWeight.w600,
  );
  final _TextStyleSpec body = const _TextStyleSpec(
    fontSize: 16,
    height: 24 / 16,
    weight: FontWeight.w400,
  );
  final _TextStyleSpec caption = const _TextStyleSpec(
    fontSize: 13,
    height: 18 / 13,
    weight: FontWeight.w400,
  );
  final _TextStyleSpec monoMd = const _TextStyleSpec(
    fontSize: 14,
    height: 20 / 14,
    weight: FontWeight.w500,
  );
  final _TextStyleSpec monoLg = const _TextStyleSpec(
    fontSize: 24,
    height: 32 / 24,
    weight: FontWeight.w600,
  );
}

class _TextStyleSpec {
  const _TextStyleSpec({
    required this.fontSize,
    required this.height,
    required this.weight,
  });

  final double fontSize;

  /// Multiplier (lineHeight / fontSize) — feed into [TextStyle.height].
  final double height;
  final FontWeight weight;
}

class _Radius {
  const _Radius();

  final double sm = 4; // inputs
  final double md = 8; // default — buttons
  final double lg = 12; // cards, modals
  final double pill = 999;
}

class _Motion {
  const _Motion();

  // Notion/GitHub feel: subtle, fast, no bounce. Easing is functional.
  final Duration fast = const Duration(milliseconds: 120);
  final Duration normal = const Duration(milliseconds: 200);
  final Duration slow = const Duration(milliseconds: 300);

  /// Functional easing. Matches the CSS `ease-out` curve in spirit.
  final Curve easing = Curves.easeOut;
}
