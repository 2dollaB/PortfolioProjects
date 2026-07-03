import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_spacing.dart';

/// BeatSync theme — Memorisely-style design system.
/// Most consumers should reach for [AppColors] / [AppSpacing] directly.
/// Legacy [AppTheme.accent], [AppTheme.heading()], etc. are kept as
/// thin re-exports so existing screens keep compiling during the rollout.
class AppTheme {
  AppTheme._();

  // ─────────────────────────────────────────────────────────────
  // Legacy color aliases — point at the new tokens.
  // Do NOT add new references to these in fresh code; use AppColors.
  // ─────────────────────────────────────────────────────────────
  // Mode-aware aliases — resolve through AppColors' semantic getters.
  static Color get background    => AppColors.bgPrimary;
  static Color get surface       => AppColors.bgSecondary;
  static Color get surfaceLight  => AppColors.bgTertiary;
  static const Color surfaceActive = Color(0xFF2A2A35);

  static const Color accent      = AppColors.brandRed;
  static const Color accentLight = Color(0xFFFF3D6E);
  static const Color accentDark  = AppColors.brandRedLight;

  static Color get textPrimary   => AppColors.textPrimary;
  static Color get textSecondary => AppColors.textSecondary;
  static Color get textMuted     => AppColors.textTertiary;

  static const Color success = AppColors.success;
  static const Color warning = AppColors.warning;
  static const Color danger  = AppColors.danger;

  static const Color zone1 = AppColors.zone1;
  static const Color zone2 = AppColors.zone2;
  static const Color zone3 = AppColors.zone3;
  static const Color zone4 = AppColors.zone4;
  static const Color zone5 = AppColors.zone5;

  // ─────────────────────────────────────────────────────────────
  // TYPOGRAPHY — Memorisely spec
  // Scale: displayXL 56 / h1 28 / h2 20 / bodyL 16 / body 14 / caption 12 / micro 10
  // ─────────────────────────────────────────────────────────────

  /// XL display — live BPM, hero numbers. Tabular figures so live updates don't shift.
  static TextStyle displayXL({Color? color, Color? glow}) {
    return GoogleFonts.spaceGrotesk(
      fontSize: 56,
      fontWeight: FontWeight.w700,
      color: color ?? AppColors.textPrimary,
      letterSpacing: -1.5,
      height: 1.0,
      fontFeatures: const [FontFeature.tabularFigures()],
      shadows: glow == null
          ? null
          : [
              Shadow(color: glow.withValues(alpha: 0.5), blurRadius: 24),
              Shadow(color: glow.withValues(alpha: 0.25), blurRadius: 48),
            ],
    );
  }

  /// H1 — screen titles.
  static TextStyle h1({Color? color}) =>
      GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimary,
        letterSpacing: -0.5,
        height: 1.2,
      );

  /// H2 — section headers, card titles.
  static TextStyle h2({Color? color}) =>
      GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.textPrimary,
        letterSpacing: -0.2,
        height: 1.3,
      );

  /// Body large (16) — primary content text.
  static TextStyle bodyLarge({
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) =>
      GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: weight,
        color: color ?? AppColors.textPrimary,
        height: 1.5,
      );

  /// Caption (12) — labels, metadata, timestamps.
  static TextStyle caption({Color? color}) =>
      GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color ?? AppColors.textSecondary,
        height: 1.4,
      );

  /// Micro (10) — zone badges, unit suffixes. Uppercase + letter-spacing applied at site.
  static TextStyle micro({Color? color}) =>
      GoogleFonts.poppins(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.textSecondary,
        letterSpacing: 0.8,
        height: 1.4,
      );

  /// Tabular number — for stat values that update live.
  static TextStyle statNumber({
    double fontSize = 20,
    FontWeight weight = FontWeight.w600,
    Color? color,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: fontSize,
        fontWeight: weight,
        color: color ?? AppColors.textPrimary,
        height: 1.1,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  // ─────────────────────────────────────────────────────────────
  // LEGACY TEXT STYLE HELPERS — kept for compatibility.
  // New code should use h1 / h2 / bodyLarge / caption / micro instead.
  // ─────────────────────────────────────────────────────────────
  static TextStyle heading({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double letterSpacing = 0,
    List<Shadow>? shadows,
  }) =>
      GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? AppColors.textPrimary,
        letterSpacing: letterSpacing,
        shadows: shadows,
      );

  static TextStyle body({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
  }) =>
      GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? AppColors.textSecondary,
      );

  static TextStyle mono({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w500,
    Color? color,
    double letterSpacing = 0.5,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color ?? AppColors.textPrimary,
        letterSpacing: letterSpacing,
      );

  static TextStyle bpmDisplay({
    double fontSize = 72,
    Color glowColor = AppColors.brandRed,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -1.5,
        fontFeatures: const [FontFeature.tabularFigures()],
        shadows: [
          Shadow(color: glowColor.withValues(alpha: 0.5), blurRadius: 24),
          Shadow(color: glowColor.withValues(alpha: 0.25), blurRadius: 48),
        ],
      );

  // ─────────────────────────────────────────────────────────────
  // CARD DECORATIONS
  // ─────────────────────────────────────────────────────────────

  /// Standard card — flat, bordered, generous radius. Default for dark mode.
  static BoxDecoration card({double radius = AppRadius.lg, Color? borderColor}) {
    return BoxDecoration(
      color: AppColors.bgSecondary,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? AppColors.border,
        width: 1,
      ),
    );
  }

  /// Elevated card — with subtle accent glow. Use for hero/highlighted cards.
  static BoxDecoration cardElevated({
    double radius = AppRadius.lg,
    Color glow = AppColors.brandRed,
    double glowAlpha = 0.08,
  }) {
    return BoxDecoration(
      color: AppColors.bgSecondary,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border, width: 1),
      boxShadow: [
        BoxShadow(
          color: glow.withValues(alpha: glowAlpha),
          blurRadius: 24,
          spreadRadius: -4,
        ),
      ],
    );
  }

  // Legacy decoration helpers — preserved so existing screens compile.
  // Refactored to use new tokens.
  static BoxDecoration boldCard({double borderRadius = AppRadius.lg}) =>
      card(radius: borderRadius);

  static BoxDecoration glowCard({
    required Color color,
    double borderRadius = AppRadius.lg,
    double intensity = 0.15,
  }) =>
      cardElevated(radius: borderRadius, glow: color, glowAlpha: intensity);

  static BoxDecoration glassmorphCard({
    double borderRadius = AppRadius.xl,
    Color tint = AppColors.brandRed,
  }) =>
      cardElevated(radius: borderRadius, glow: tint, glowAlpha: 0.08);

  static BoxDecoration frostedCard({double borderRadius = AppRadius.xl}) =>
      card(radius: borderRadius);

  static BoxDecoration metricCard({
    Color? accentColor,
    double borderRadius = AppRadius.lg,
  }) =>
      card(
        radius: borderRadius,
        borderColor: (accentColor ?? AppColors.brandRed).withValues(alpha: 0.12),
      );

  // ─────────────────────────────────────────────────────────────
  // THEME DATA
  // ─────────────────────────────────────────────────────────────

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.darkBgPrimary,
      colorScheme: const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: AppColors.brandRed,
        onPrimary: Colors.white,
        secondary: AppColors.brandRed,
        onSecondary: Colors.white,
        surface: AppColors.darkBgSecondary,
        onSurface: AppColors.darkTextPrimary,
        surfaceContainerHighest: AppColors.darkBgTertiary,
        error: AppColors.danger,
        onError: Colors.white,
        outline: AppColors.darkBorder,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
        bodyColor: AppColors.darkTextPrimary,
        displayColor: AppColors.darkTextPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.darkTextPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandRed,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandRed,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: AppColors.brandRed, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brandRed,
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkBgSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.brandRed, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        hintStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: AppColors.darkTextTertiary,
        ),
        labelStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: AppColors.darkTextSecondary,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.brandRed,
        inactiveTrackColor: AppColors.darkBgTertiary,
        thumbColor: AppColors.brandRed,
        overlayColor: AppColors.brandRed.withValues(alpha: 0.2),
        valueIndicatorColor: AppColors.brandRed,
        valueIndicatorTextStyle: const TextStyle(color: Colors.white),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkBgSecondary,
        indicatorColor: AppColors.brandRed.withValues(alpha: 0.15),
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.brandRed : AppColors.darkTextSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.brandRed : AppColors.darkTextSecondary,
            size: 24,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
    );
  }

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.lightBgPrimary,
      colorScheme: const ColorScheme.light(
        brightness: Brightness.light,
        primary: AppColors.brandRedLight,
        onPrimary: Colors.white,
        secondary: AppColors.brandRedLight,
        onSecondary: Colors.white,
        surface: AppColors.lightBgSecondary,
        onSurface: AppColors.lightTextPrimary,
        surfaceContainerHighest: AppColors.lightBgTertiary,
        error: AppColors.danger,
        onError: Colors.white,
        outline: AppColors.lightBorder,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
        bodyColor: AppColors.lightTextPrimary,
        displayColor: AppColors.lightTextPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.lightTextPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.lightTextPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandRedLight,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandRedLight,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: AppColors.brandRedLight, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          // Must mirror the dark theme: lerping a theme that sets textStyle
          // against one that falls back to labelLarge (inherit: false)
          // throws mid-animation and cascades into GlobalKey errors.
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brandRedLight,
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightBgSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.brandRedLight, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        // Mirrors the dark theme (see the outlinedButtonTheme note).
        hintStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: AppColors.lightTextTertiary,
        ),
        labelStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: AppColors.lightTextSecondary,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.brandRedLight,
        inactiveTrackColor: AppColors.lightBgTertiary,
        thumbColor: AppColors.brandRedLight,
        overlayColor: AppColors.brandRedLight.withValues(alpha: 0.2),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.lightBgSecondary,
        indicatorColor: AppColors.brandRedLight.withValues(alpha: 0.12),
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.brandRedLight : AppColors.lightTextSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.brandRedLight : AppColors.lightTextSecondary,
            size: 24,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
