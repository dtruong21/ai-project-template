/// Material 3 theme factory — Notion + GitHub.
///
/// Two top-level builders: [notionGithubLightTheme] and [notionGithubDarkTheme].
/// Each returns a [ThemeData] with:
///   - ColorScheme.fromSeed pinned to a [DynamicSchemeVariant]
///   - Inter body / JetBrains Mono via google_fonts
///   - [NotionGithubExtensions] for tokens MD3 doesn't natively cover
///     (heatmap palette, mono font family, semantic warning/success scales).
///
/// Components read raw values from `tokens.dart`; this file wires them into
/// the Material 3 surfaces (ColorScheme, TextTheme, etc.).
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

ThemeData notionGithubLightTheme() => _buildTheme(Brightness.light);

ThemeData notionGithubDarkTheme() => _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final bool isDark = brightness == Brightness.dark;
  final _LightOrDark c = isDark ? _LightOrDark.dark() : _LightOrDark.light();

  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: c.accent,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.neutral,
  ).copyWith(
    surface: c.surface,
    onSurface: c.text,
    surfaceContainerLowest: c.bg,
    surfaceContainerLow: c.surface,
    surfaceContainer: c.surface,
    surfaceContainerHigh: c.surface,
    surfaceContainerHighest: c.surface,
    onSurfaceVariant: c.muted,
    outline: c.border,
    outlineVariant: c.divider,
    primary: c.accent,
    onPrimary: isDark ? c.bg : Colors.white,
    error: c.danger,
    onError: Colors.white,
  );

  final TextTheme baseText = GoogleFonts.interTextTheme(
    ThemeData(brightness: brightness).textTheme,
  );

  TextStyle _spec(
    _TextSpec spec, {
    Color? color,
    String? family,
  }) {
    if (family == NotionGithubTokens.typography.monoFamily) {
      return GoogleFonts.jetBrainsMono(
        fontSize: spec.fontSize,
        height: spec.height,
        fontWeight: spec.weight,
        color: color ?? c.text,
      );
    }
    return GoogleFonts.inter(
      fontSize: spec.fontSize,
      height: spec.height,
      fontWeight: spec.weight,
      color: color ?? c.text,
    );
  }

  final _Typography t = NotionGithubTokens.typography;

  final TextTheme textTheme = baseText.copyWith(
    // Display / headlines — Notion-style page titles + section headers.
    displayLarge: _spec(_TextSpec.from(t.display), color: c.text),
    displayMedium: _spec(_TextSpec.from(t.display), color: c.text),
    displaySmall: _spec(_TextSpec.from(t.h1), color: c.text),
    headlineLarge: _spec(_TextSpec.from(t.h1), color: c.text),
    headlineMedium: _spec(_TextSpec.from(t.h1), color: c.text),
    headlineSmall: _spec(_TextSpec.from(t.h2), color: c.text),
    titleLarge: _spec(_TextSpec.from(t.h2), color: c.text),
    titleMedium: _spec(_TextSpec.from(t.body), color: c.text),
    titleSmall: _spec(_TextSpec.from(t.caption), color: c.muted),
    // Body — default reading text.
    bodyLarge: _spec(_TextSpec.from(t.body), color: c.text),
    bodyMedium: _spec(_TextSpec.from(t.body), color: c.text),
    bodySmall: _spec(_TextSpec.from(t.caption), color: c.muted),
    // Labels — buttons + small UI.
    labelLarge: _spec(_TextSpec.from(t.body), color: c.text),
    labelMedium: _spec(_TextSpec.from(t.caption), color: c.text),
    labelSmall: _spec(_TextSpec.from(t.caption), color: c.muted),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    dividerColor: c.divider,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NotionGithubTokens.radius.lg),
        side: BorderSide(color: c.border),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: DividerThemeData(
      color: c.divider,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      hintStyle: textTheme.bodyMedium?.copyWith(color: c.subtle),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NotionGithubTokens.radius.sm),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NotionGithubTokens.radius.sm),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NotionGithubTokens.radius.sm),
        borderSide: BorderSide(color: c.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NotionGithubTokens.radius.sm),
        borderSide: BorderSide(color: c.danger),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: isDark ? c.bg : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NotionGithubTokens.radius.md),
        ),
        textStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.text,
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NotionGithubTokens.radius.md),
        ),
        textStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.accent,
        textStyle: textTheme.labelLarge,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surface,
      side: BorderSide(color: c.border),
      labelStyle: textTheme.labelMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NotionGithubTokens.radius.pill),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.text,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: c.bg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NotionGithubTokens.radius.md),
      ),
    ),
    extensions: <ThemeExtension<dynamic>>[
      NotionGithubExtensions(
        heatmap: c.heatmap,
        monoFamily: NotionGithubTokens.typography.monoFamily,
        success: c.success,
        warning: c.warning,
        danger: c.danger,
        muted: c.muted,
        subtle: c.subtle,
        divider: c.divider,
        motionFast: NotionGithubTokens.motion.fast,
        motionNormal: NotionGithubTokens.motion.normal,
        motionSlow: NotionGithubTokens.motion.slow,
        motionEasing: NotionGithubTokens.motion.easing,
      ),
    ],
  );
}

/// Tokens that don't map cleanly onto Material 3's ColorScheme / TextTheme.
///
/// Access from widgets via:
/// ```dart
/// final ext = Theme.of(context).extension<NotionGithubExtensions>()!;
/// final cellColor = ext.heatmap[intensity];
/// ```
@immutable
class NotionGithubExtensions extends ThemeExtension<NotionGithubExtensions> {
  const NotionGithubExtensions({
    required this.heatmap,
    required this.monoFamily,
    required this.success,
    required this.warning,
    required this.danger,
    required this.muted,
    required this.subtle,
    required this.divider,
    required this.motionFast,
    required this.motionNormal,
    required this.motionSlow,
    required this.motionEasing,
  });

  /// 5-step GitHub contribution scale, low → high.
  final List<Color> heatmap;

  /// Mono font family name (resolved via google_fonts at call site).
  final String monoFamily;

  final Color success;
  final Color warning;
  final Color danger;
  final Color muted;
  final Color subtle;
  final Color divider;

  final Duration motionFast;
  final Duration motionNormal;
  final Duration motionSlow;
  final Curve motionEasing;

  /// Convenience: build a mono [TextStyle] off the registered family.
  TextStyle monoTextStyle({
    required double fontSize,
    required double height,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      height: height,
      fontWeight: fontWeight,
      color: color,
    );
  }

  @override
  NotionGithubExtensions copyWith({
    List<Color>? heatmap,
    String? monoFamily,
    Color? success,
    Color? warning,
    Color? danger,
    Color? muted,
    Color? subtle,
    Color? divider,
    Duration? motionFast,
    Duration? motionNormal,
    Duration? motionSlow,
    Curve? motionEasing,
  }) {
    return NotionGithubExtensions(
      heatmap: heatmap ?? this.heatmap,
      monoFamily: monoFamily ?? this.monoFamily,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      muted: muted ?? this.muted,
      subtle: subtle ?? this.subtle,
      divider: divider ?? this.divider,
      motionFast: motionFast ?? this.motionFast,
      motionNormal: motionNormal ?? this.motionNormal,
      motionSlow: motionSlow ?? this.motionSlow,
      motionEasing: motionEasing ?? this.motionEasing,
    );
  }

  @override
  NotionGithubExtensions lerp(
    ThemeExtension<NotionGithubExtensions>? other,
    double t,
  ) {
    if (other is! NotionGithubExtensions) return this;
    return NotionGithubExtensions(
      heatmap: <Color>[
        for (int i = 0; i < heatmap.length; i++)
          Color.lerp(heatmap[i], other.heatmap[i], t) ?? heatmap[i],
      ],
      monoFamily: t < 0.5 ? monoFamily : other.monoFamily,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      motionFast: t < 0.5 ? motionFast : other.motionFast,
      motionNormal: t < 0.5 ? motionNormal : other.motionNormal,
      motionSlow: t < 0.5 ? motionSlow : other.motionSlow,
      motionEasing: t < 0.5 ? motionEasing : other.motionEasing,
    );
  }
}

// ---------------------------------------------------------------------------
// Internal helpers — keep theme builder readable.
// ---------------------------------------------------------------------------

class _LightOrDark {
  const _LightOrDark._({
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
    required this.heatmap,
  });

  factory _LightOrDark.light() => _LightOrDark._(
        bg: NotionGithubTokens.light.bg,
        surface: NotionGithubTokens.light.surface,
        border: NotionGithubTokens.light.border,
        divider: NotionGithubTokens.light.divider,
        text: NotionGithubTokens.light.text,
        muted: NotionGithubTokens.light.muted,
        subtle: NotionGithubTokens.light.subtle,
        accent: NotionGithubTokens.light.accent,
        success: NotionGithubTokens.light.success,
        danger: NotionGithubTokens.light.danger,
        warning: NotionGithubTokens.light.warning,
        heatmap: NotionGithubTokens.light.heatmap,
      );

  factory _LightOrDark.dark() => _LightOrDark._(
        bg: NotionGithubTokens.dark.bg,
        surface: NotionGithubTokens.dark.surface,
        border: NotionGithubTokens.dark.border,
        divider: NotionGithubTokens.dark.divider,
        text: NotionGithubTokens.dark.text,
        muted: NotionGithubTokens.dark.muted,
        subtle: NotionGithubTokens.dark.subtle,
        accent: NotionGithubTokens.dark.accent,
        success: NotionGithubTokens.dark.success,
        danger: NotionGithubTokens.dark.danger,
        warning: NotionGithubTokens.dark.warning,
        heatmap: NotionGithubTokens.dark.heatmap,
      );

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
  final List<Color> heatmap;
}

class _TextSpec {
  const _TextSpec({
    required this.fontSize,
    required this.height,
    required this.weight,
  });

  factory _TextSpec.from(dynamic spec) {
    // The token specs are private types in tokens.dart; we duck-type their
    // shape (fontSize/height/weight) to avoid leaking those types from the
    // tokens library.
    // ignore: avoid_dynamic_calls
    return _TextSpec(
      // ignore: avoid_dynamic_calls
      fontSize: spec.fontSize as double,
      // ignore: avoid_dynamic_calls
      height: spec.height as double,
      // ignore: avoid_dynamic_calls
      weight: spec.weight as FontWeight,
    );
  }

  final double fontSize;
  final double height;
  final FontWeight weight;
}
