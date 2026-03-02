import 'package:flutter/material.dart';

/// BeatSync App Theme — Dark, Premium, Fitness-focused
/// Palette v2 (2025/26) — Deeper darks, brighter accents
class AppTheme {
  // Core surfaces
  static const Color background = Color(0xFF020617);    // Deep ocean — less OLED smear
  static const Color surface = Color(0xFF0F172A);        // Card background
  static const Color surfaceLight = Color(0xFF1E293B);   // Elevated surface

  // Accent — Lighter Indigo for better readability on deep dark
  static const Color accent = Color(0xFF818CF8);
  static const Color accentLight = Color(0xFFA5B4FC);

  // Semantic colors
  static const Color success = Color(0xFF39FF14);        // Electric Lime — confirmations
  static const Color warning = Color(0xFFFACC15);        // Amber — alerts without alarm

  // Text hierarchy
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF94A3B8);  // Slightly cooler slate
  static const Color textMuted = Color(0xFF64748B);      // Slate-500 — better contrast

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          surface: surface,
          primary: accent,
          secondary: accentLight,
          onSurface: textPrimary,
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          iconTheme: IconThemeData(color: textPrimary),
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: accentLight,
          ),
        ),
      );
}
