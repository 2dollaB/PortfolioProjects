import 'package:flutter/material.dart';

/// Heart Rate Zone configuration and colors
class HrZones {
  /// Zone colors — industry standard for fitness displays
  static const Map<int, Color> colors = {
    0: Color(0xFF6B7280), // Rest — Grey
    1: Color(0xFF3B82F6), // Zone 1 — Blue (Very Light)
    2: Color(0xFF22C55E), // Zone 2 — Green (Light)
    3: Color(0xFFEAB308), // Zone 3 — Yellow (Moderate)
    4: Color(0xFFF97316), // Zone 4 — Orange (Hard)
    5: Color(0xFFEF4444), // Zone 5 — Red (Maximum)
  };

  /// Zone background colors (slightly transparent for UI backgrounds)
  static Color backgroundColor(int zone) =>
      (colors[zone] ?? colors[0]!).withValues(alpha: 0.15);

  /// Zone glow color for animations
  static Color glowColor(int zone) =>
      (colors[zone] ?? colors[0]!).withValues(alpha: 0.4);

  /// Percentage ranges per zone
  static const Map<int, String> percentRanges = {
    0: '< 50%',
    1: '50-59%',
    2: '60-69%',
    3: '70-79%',
    4: '80-89%',
    5: '90-100%',
  };

  /// Zone names
  static const Map<int, String> names = {
    0: 'Rest',
    1: 'Very Light',
    2: 'Light',
    3: 'Moderate',
    4: 'Hard',
    5: 'Maximum',
  };

  /// Zone icons
  static const Map<int, IconData> icons = {
    0: Icons.hotel,
    1: Icons.directions_walk,
    2: Icons.directions_run,
    3: Icons.fitness_center,
    4: Icons.local_fire_department,
    5: Icons.bolt,
  };

  /// Calculate zone from BPM and HRmax
  static int fromBpm(int bpm, int hrMax) {
    if (hrMax <= 0) return 0;
    final pct = (bpm / hrMax * 100).round();
    if (pct < 50) return 0;
    if (pct < 60) return 1;
    if (pct < 70) return 2;
    if (pct < 80) return 3;
    if (pct < 90) return 4;
    return 5;
  }

  /// Calculate % of HRmax
  static int percentOfMax(int bpm, int hrMax) {
    if (hrMax <= 0) return 0;
    return (bpm / hrMax * 100).round().clamp(0, 200);
  }

  /// Calculate HRmax using Tanaka formula (most accurate for general population)
  /// HRmax = 208 - (0.7 × age)
  static int tanaka(int age) => (208 - (0.7 * age)).round();

  /// Calculate HRmax using HUNT formula (optimized for athletic individuals)
  /// HRmax = 211 - (0.64 × age)
  static int hunt(int age) => (211 - (0.64 * age)).round();

  /// Calculate HRmax using Gulati formula (specifically for women)
  /// HRmax = 206 - (0.88 × age)
  static int gulati(int age) => (206 - (0.88 * age)).round();
}
