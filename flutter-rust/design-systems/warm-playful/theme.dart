/// Material 3 theme for the Warm Playful design system.
///
/// Builds [ThemeData] from a seed color via [ColorScheme.fromSeed], then
/// overrides cream/peach surfaces and warm brown text/borders to match the
/// hand-picked tokens. The 5-color category palette is exposed through a
/// [ThemeExtension] so widgets can do:
///
/// ```dart
/// final palette = Theme.of(context).extension<WarmPlayfulExtensions>()!;
/// Container(color: palette.peach);
/// ```
///
/// Typography is Nunito via `google_fonts`. Heavier weights (700/800) are
/// used for titles — Nunito carries weight well.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Builds the Warm Playful [ThemeData] for the given [brightness].
ThemeData buildWarmPlayfulTheme(Brightness brightness) {
  final isLight = brightness == Brightness.light;

  final bg = isLight ? WarmPlayfulColorsLight.bg : WarmPlayfulColorsDark.bg;
  final surface =
      isLight ? WarmPlayfulColorsLight.surface : WarmPlayfulColorsDark.surface;
  final border =
      isLight ? WarmPlayfulColorsLight.border : WarmPlayfulColorsDark.border;
  final divider =
      isLight ? WarmPlayfulColorsLight.divider : WarmPlayfulColorsDark.divider;
  final text =
      isLight ? WarmPlayfulColorsLight.text : WarmPlayfulColorsDark.text;
  final muted =
      isLight ? WarmPlayfulColorsLight.muted : WarmPlayfulColorsDark.muted;
  final accent =
      isLight ? WarmPlayfulColorsLight.accent : WarmPlayfulColorsDark.accent;
  final success =
      isLight ? WarmPlayfulColorsLight.success : WarmPlayfulColorsDark.success;
  final danger =
      isLight ? WarmPlayfulColorsLight.danger : WarmPlayfulColorsDark.danger;
  final warning =
      isLight ? WarmPlayfulColorsLight.warning : WarmPlayfulColorsDark.warning;

  final scheme = ColorScheme.fromSeed(
    seedColor: WarmPlayfulTokens.seed,
    brightness: brightness,
    // Pin the variant explicitly — Material 3 may change defaults.
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  ).copyWith(
    primary: accent,
    onPrimary: WarmPlayfulColorsLight.bg, // cream on coral reads well
    surface: surface,
    onSurface: text,
    surfaceContainerLowest: bg,
    surfaceContainerLow: bg,
    surfaceContainer: surface,
    surfaceContainerHigh: surface,
    surfaceContainerHighest: surface,
    outline: border,
    outlineVariant: divider,
    error: danger,
    onError: WarmPlayfulColorsLight.bg,
    tertiary: success,
  );

  // Nunito body text via google_fonts. Apply tuned weights/heights.
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    canvasColor: bg,
    dividerColor: divider,
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );

  final textTheme = GoogleFonts.nunitoTextTheme(base.textTheme).copyWith(
    displayLarge: TextStyle(
      fontSize: WarmPlayfulType.displaySize,
      height: WarmPlayfulType.displayHeight,
      fontWeight: WarmPlayfulType.displayWeight,
      color: text,
    ),
    displayMedium: TextStyle(
      fontSize: WarmPlayfulType.displaySize,
      height: WarmPlayfulType.displayHeight,
      fontWeight: WarmPlayfulType.displayWeight,
      color: text,
    ),
    headlineLarge: TextStyle(
      fontSize: WarmPlayfulType.h1Size,
      height: WarmPlayfulType.h1Height,
      fontWeight: WarmPlayfulType.h1Weight,
      color: text,
    ),
    headlineMedium: TextStyle(
      fontSize: WarmPlayfulType.h1Size,
      height: WarmPlayfulType.h1Height,
      fontWeight: WarmPlayfulType.h1Weight,
      color: text,
    ),
    titleLarge: TextStyle(
      fontSize: WarmPlayfulType.h2Size,
      height: WarmPlayfulType.h2Height,
      fontWeight: WarmPlayfulType.h2Weight,
      color: text,
    ),
    titleMedium: TextStyle(
      fontSize: WarmPlayfulType.h2Size,
      height: WarmPlayfulType.h2Height,
      fontWeight: WarmPlayfulType.h2Weight,
      color: text,
    ),
    bodyLarge: TextStyle(
      fontSize: WarmPlayfulType.bodySize,
      height: WarmPlayfulType.bodyHeight,
      fontWeight: WarmPlayfulType.bodyWeight,
      color: text,
    ),
    bodyMedium: TextStyle(
      fontSize: WarmPlayfulType.bodySize,
      height: WarmPlayfulType.bodyHeight,
      fontWeight: WarmPlayfulType.bodyWeight,
      color: text,
    ),
    bodySmall: TextStyle(
      fontSize: WarmPlayfulType.captionSize,
      height: WarmPlayfulType.captionHeight,
      fontWeight: WarmPlayfulType.captionWeight,
      color: muted,
    ),
    labelLarge: TextStyle(
      fontSize: WarmPlayfulType.bodySize,
      height: WarmPlayfulType.bodyHeight,
      fontWeight: FontWeight.w700, // buttons get weight
      color: text,
    ),
    labelMedium: TextStyle(
      fontSize: WarmPlayfulType.captionSize,
      height: WarmPlayfulType.captionHeight,
      fontWeight: WarmPlayfulType.captionWeight,
      color: muted,
    ),
  );

  return base.copyWith(
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.lg),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: WarmPlayfulColorsLight.bg,
        elevation: 0,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: WarmPlayfulSpacing.s5,
          vertical: WarmPlayfulSpacing.s3,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WarmPlayfulRadius.md),
        ),
        textStyle: textTheme.labelLarge?.copyWith(
          color: WarmPlayfulColorsLight.bg,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: surface,
        foregroundColor: text,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: WarmPlayfulSpacing.s5,
          vertical: WarmPlayfulSpacing.s3,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WarmPlayfulRadius.md),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: text,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: WarmPlayfulSpacing.s4,
          vertical: WarmPlayfulSpacing.s3,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WarmPlayfulRadius.md),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: WarmPlayfulSpacing.s4,
        vertical: WarmPlayfulSpacing.s3,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.sm),
        borderSide: BorderSide(color: accent, width: 2),
      ),
      hintStyle: textTheme.bodyMedium?.copyWith(color: muted),
      labelStyle: textTheme.bodyMedium?.copyWith(color: muted),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      selectedColor: accent,
      labelStyle: textTheme.bodySmall?.copyWith(color: text),
      secondaryLabelStyle:
          textTheme.bodySmall?.copyWith(color: WarmPlayfulColorsLight.bg),
      side: BorderSide(color: border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.pill),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: WarmPlayfulSpacing.s3,
        vertical: WarmPlayfulSpacing.s1,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(WarmPlayfulRadius.xl),
        ),
      ),
      showDragHandle: true,
      dragHandleColor: border,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WarmPlayfulRadius.lg),
      ),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    dividerTheme: DividerThemeData(
      color: divider,
      thickness: 1,
      space: 1,
    ),
    iconTheme: IconThemeData(color: text, size: 24),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    extensions: <ThemeExtension<dynamic>>[
      WarmPlayfulExtensions(
        // Category palette
        peach: isLight
            ? WarmPlayfulColorsLight.palettePeach
            : WarmPlayfulColorsDark.palettePeach,
        sage: isLight
            ? WarmPlayfulColorsLight.paletteSage
            : WarmPlayfulColorsDark.paletteSage,
        butter: isLight
            ? WarmPlayfulColorsLight.paletteButter
            : WarmPlayfulColorsDark.paletteButter,
        lavender: isLight
            ? WarmPlayfulColorsLight.paletteLavender
            : WarmPlayfulColorsDark.paletteLavender,
        sky: isLight
            ? WarmPlayfulColorsLight.paletteSky
            : WarmPlayfulColorsDark.paletteSky,
        // Semantic extras not in ColorScheme
        success: success,
        warning: warning,
        danger: danger,
        // Surfaces + text shades not cleanly mapped to ColorScheme
        muted: muted,
        subtle:
            isLight ? WarmPlayfulColorsLight.subtle : WarmPlayfulColorsDark.subtle,
        border: border,
        divider: divider,
      ),
    ],
  );
}

/// Theme extension carrying the Warm Playful 5-color category palette and a
/// handful of semantic colors that don't cleanly map to Material's
/// [ColorScheme] (muted text, divider, success/warning scales).
///
/// Access via:
/// ```dart
/// final wp = Theme.of(context).extension<WarmPlayfulExtensions>()!;
/// Container(color: wp.peach);
/// Text('...', style: TextStyle(color: wp.muted));
/// ```
@immutable
class WarmPlayfulExtensions extends ThemeExtension<WarmPlayfulExtensions> {
  const WarmPlayfulExtensions({
    required this.peach,
    required this.sage,
    required this.butter,
    required this.lavender,
    required this.sky,
    required this.success,
    required this.warning,
    required this.danger,
    required this.muted,
    required this.subtle,
    required this.border,
    required this.divider,
  });

  // Category palette — the signature 5.
  final Color peach;
  final Color sage;
  final Color butter;
  final Color lavender;
  final Color sky;

  // Semantic colors not in ColorScheme.
  final Color success;
  final Color warning;
  final Color danger;

  // Surface/text shades not in ColorScheme.
  final Color muted;
  final Color subtle;
  final Color border;
  final Color divider;

  /// Convenient ordered list of the 5 category colors, e.g. for assigning
  /// a habit category color by index.
  List<Color> get categoryPalette =>
      <Color>[peach, sage, butter, lavender, sky];

  @override
  WarmPlayfulExtensions copyWith({
    Color? peach,
    Color? sage,
    Color? butter,
    Color? lavender,
    Color? sky,
    Color? success,
    Color? warning,
    Color? danger,
    Color? muted,
    Color? subtle,
    Color? border,
    Color? divider,
  }) {
    return WarmPlayfulExtensions(
      peach: peach ?? this.peach,
      sage: sage ?? this.sage,
      butter: butter ?? this.butter,
      lavender: lavender ?? this.lavender,
      sky: sky ?? this.sky,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      muted: muted ?? this.muted,
      subtle: subtle ?? this.subtle,
      border: border ?? this.border,
      divider: divider ?? this.divider,
    );
  }

  @override
  WarmPlayfulExtensions lerp(
    ThemeExtension<WarmPlayfulExtensions>? other,
    double t,
  ) {
    if (other is! WarmPlayfulExtensions) return this;
    return WarmPlayfulExtensions(
      peach: Color.lerp(peach, other.peach, t)!,
      sage: Color.lerp(sage, other.sage, t)!,
      butter: Color.lerp(butter, other.butter, t)!,
      lavender: Color.lerp(lavender, other.lavender, t)!,
      sky: Color.lerp(sky, other.sky, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}
