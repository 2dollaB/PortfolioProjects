import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── BACKGROUND ─────────────────────────────────
  static const Color background    = Color(0xFF0A0A12);
  static const Color surface       = Color(0xFF141420);
  static const Color surfaceLight  = Color(0xFF1E1E2E);
  static const Color surfaceActive = Color(0xFF282838);

  // ── BRAND ──────────────────────────────────────
  static const Color accent      = Color(0xFFE63946);  // Crimson Red
  static const Color accentLight = Color(0xFFFF6B6B);
  static const Color accentDark  = Color(0xFFC41E30);

  // ── TEXT ────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted     = Color(0xFF555566);

  // ── SEMANTIC ───────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFEAB308);
  static const Color danger  = Color(0xFFEF4444);

  // ── ZONE COLORS ────────────────────────────────
  static const Color zone1 = Color(0xFF3B82F6);
  static const Color zone2 = Color(0xFF22C55E);
  static const Color zone3 = Color(0xFFEAB308);
  static const Color zone4 = Color(0xFFF97316);
  static const Color zone5 = Color(0xFFEF4444);

  // ── TYPOGRAPHY ─────────────────────────────────

  static TextStyle heading({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w700,
    Color color = textPrimary,
    double letterSpacing = 0,
    List<Shadow>? shadows,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      shadows: shadows,
    );
  }

  static TextStyle body({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = textSecondary,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  static TextStyle mono({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w500,
    Color color = textPrimary,
    double letterSpacing = 0.5,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle bpmDisplay({
    double fontSize = 72,
    Color glowColor = accent,
  }) {
    return GoogleFonts.orbitron(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      color: textPrimary,
      letterSpacing: -1,
      fontFeatures: const [FontFeature.tabularFigures()],
      shadows: [
        Shadow(color: glowColor.withValues(alpha: 0.6), blurRadius: 24),
        Shadow(color: glowColor.withValues(alpha: 0.3), blurRadius: 48),
      ],
    );
  }

  // ── CARD DECORATIONS ───────────────────────────

  static BoxDecoration boldCard({double borderRadius = 16}) {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF181828), surface],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1),
    );
  }

  static BoxDecoration glowCard({
    required Color color,
    double borderRadius = 16,
    double intensity = 0.15,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: 0.06),
          surface,
        ],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: intensity),
          blurRadius: 24,
          spreadRadius: -4,
        ),
      ],
    );
  }

  /// 7.1 — Glassmorphism card
  static BoxDecoration glassmorphCard({
    double borderRadius = 20,
    Color tint = accent,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          tint.withValues(alpha: 0.08),
          const Color(0xFF151524).withValues(alpha: 0.85),
        ],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
      boxShadow: [
        BoxShadow(
          color: tint.withValues(alpha: 0.08),
          blurRadius: 32,
          spreadRadius: -8,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  /// Frosted glass card
  static BoxDecoration frostedCard({double borderRadius = 20}) {
    return BoxDecoration(
      color: const Color(0xFF151524).withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  /// Metric card with subtle accent
  static BoxDecoration metricCard({Color? accentColor, double borderRadius = 16}) {
    final c = accentColor ?? accent;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          surface,
          c.withValues(alpha: 0.04),
        ],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: c.withValues(alpha: 0.1), width: 1),
    );
  }

  // ── THEME DATA ─────────────────────────────────

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: accent,
        secondary: accentLight,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: surfaceLight,
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.2),
        valueIndicatorColor: accent,
        valueIndicatorTextStyle: const TextStyle(color: Colors.white),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
    );
  }

  /// 9.4 — Light theme for toggle
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F5F7),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      colorScheme: const ColorScheme.light(
        surface: Colors.white,
        primary: accent,
        secondary: accentLight,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1A1A2E),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        inactiveTrackColor: const Color(0xFFE0E0E0),
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.2),
        valueIndicatorColor: accent,
        valueIndicatorTextStyle: const TextStyle(color: Colors.white),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
      ),
    );
  }
}
