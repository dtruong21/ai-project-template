// Theme — Linear / Vercel minimal
//
// Material 3 ColorScheme.fromSeed pinned to Linear's purple-blue, with the
// rest of the palette wired in via overrides + a ThemeExtension for tokens
// that don't map to a ColorScheme slot (the divider scale, KeyboardHint
// chip styling, etc).
//
// Components reach for tokens via:
//   - Theme.of(context).colorScheme        // accent, surface, etc.
//   - Theme.of(context).textTheme          // body / titleLarge / displaySmall
//   - Theme.of(context).extension<AppPalette>()!  // muted, divider, hint
//
// Never import `tokens.dart` from a screen — go through the theme.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// App-specific tokens that don't fit Material's ColorScheme cleanly.
/// Accessed via `Theme.of(context).extension<AppPalette>()!`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.muted,
    required this.subtle,
    required this.divider,
    required this.success,
    required this.warning,
    required this.danger,
    required this.hintBackground,
    required this.hintBorder,
    required this.hintText,
  });

  /// Secondary body text — captions, metadata.
  final Color muted;

  /// Tertiary text — placeholders, disabled labels.
  final Color subtle;

  /// Hairline divider between rows. Slightly lighter than `border`.
  final Color divider;

  final Color success;
  final Color warning;
  final Color danger;

  // KeyboardHint chip — see DESIGN.md.
  final Color hintBackground;
  final Color hintBorder;
  final Color hintText;

  @override
  AppPalette copyWith({
    Color? muted,
    Color? subtle,
    Color? divider,
    Color? success,
    Color? warning,
    Color? danger,
    Color? hintBackground,
    Color? hintBorder,
    Color? hintText,
  }) {
    return AppPalette(
      muted: muted ?? this.muted,
      subtle: subtle ?? this.subtle,
      divider: divider ?? this.divider,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      hintBackground: hintBackground ?? this.hintBackground,
      hintBorder: hintBorder ?? this.hintBorder,
      hintText: hintText ?? this.hintText,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      muted: Color.lerp(muted, other.muted, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      hintBackground: Color.lerp(hintBackground, other.hintBackground, t)!,
      hintBorder: Color.lerp(hintBorder, other.hintBorder, t)!,
      hintText: Color.lerp(hintText, other.hintText, t)!,
    );
  }
}

/// Builds the Linear-minimal [ThemeData] for the requested [brightness].
ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final palette = isDark ? AppColors.dark : AppColors.light;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.seed,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.neutral,
  ).copyWith(
    primary: palette.accent,
    onPrimary: isDark ? AppColors.dark.bg : Colors.white,
    surface: palette.bg,
    onSurface: palette.text,
    surfaceContainerLowest: palette.bg,
    surfaceContainerLow: palette.surface,
    surfaceContainer: palette.surface,
    surfaceContainerHigh: palette.surface,
    surfaceContainerHighest: palette.surface,
    outline: palette.border,
    outlineVariant: palette.divider,
    error: palette.danger,
  );

  final textTheme = _buildTextTheme(palette.text, palette.muted);

  final appPalette = AppPalette(
    muted: palette.muted,
    subtle: palette.subtle,
    divider: palette.divider,
    success: palette.success,
    warning: palette.warning,
    danger: palette.danger,
    hintBackground: palette.surface,
    hintBorder: palette.border,
    hintText: palette.muted,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: palette.bg,
    canvasColor: palette.bg,
    dividerColor: palette.divider,
    dividerTheme: DividerThemeData(
      color: palette.divider,
      thickness: 1,
      space: 1,
    ),
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
      },
    ),
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: palette.bg,
      foregroundColor: palette.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: palette.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        // Primary CTA = pure black/white inversion. See DESIGN.md.
        backgroundColor: palette.text,
        foregroundColor: palette.bg,
        elevation: 0,
        shadowColor: Colors.transparent,
        textStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s5,
          vertical: AppSpacing.s3,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.accent,
        foregroundColor: Colors.white,
        textStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s5,
          vertical: AppSpacing.s3,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: palette.text,
        textStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s3,
          vertical: AppSpacing.s2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.text,
        side: BorderSide(color: palette.border),
        textStyle: AppTypography.body.copyWith(fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s5,
          vertical: AppSpacing.s3,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      hintStyle: AppTypography.body.copyWith(color: palette.subtle),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s3,
        vertical: AppSpacing.s3,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: palette.text),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: palette.danger),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: palette.text,
      textColor: palette.text,
      tileColor: palette.bg,
      minVerticalPadding: AppSpacing.s2,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      shape: const RoundedRectangleBorder(),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: palette.border),
      ),
      barrierColor: AppColors.dark.bg.withValues(alpha: 0.6),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: palette.surface,
      modalBarrierColor: AppColors.dark.bg.withValues(alpha: 0.6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.text,
      contentTextStyle: AppTypography.body.copyWith(color: palette.bg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
    iconTheme: IconThemeData(color: palette.text, size: 20),
    extensions: <ThemeExtension<dynamic>>[appPalette],
  );
}

TextTheme _buildTextTheme(Color text, Color muted) {
  // GoogleFonts.interTextTheme bakes Inter into every slot; we then override
  // sizes/weights/tracking to match Linear's ramp exactly.
  final base = GoogleFonts.interTextTheme();

  TextStyle apply(TextStyle template, {Color? color}) {
    return base.bodyMedium!
        .copyWith(
          fontSize: template.fontSize,
          height: template.height,
          fontWeight: template.fontWeight,
          letterSpacing: template.letterSpacing,
          color: color ?? text,
        );
  }

  return TextTheme(
    displayLarge: apply(AppTypography.display),
    displayMedium: apply(AppTypography.display),
    displaySmall: apply(AppTypography.display),
    headlineLarge: apply(AppTypography.h1),
    headlineMedium: apply(AppTypography.h1),
    headlineSmall: apply(AppTypography.h2),
    titleLarge: apply(AppTypography.h1),
    titleMedium: apply(AppTypography.h2),
    titleSmall: apply(AppTypography.body.copyWith(fontWeight: FontWeight.w600)),
    bodyLarge: apply(AppTypography.body),
    bodyMedium: apply(AppTypography.body),
    bodySmall: apply(AppTypography.caption, color: muted),
    labelLarge: apply(AppTypography.body.copyWith(fontWeight: FontWeight.w500)),
    labelMedium: apply(AppTypography.caption),
    labelSmall: apply(AppTypography.caption, color: muted),
  );
}
