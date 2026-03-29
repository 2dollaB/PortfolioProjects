import 'package:shared_preferences/shared_preferences.dart';

/// 6.2 — Unit preference system: metric vs imperial
/// Central source of truth for display units across the app.
/// Data is always stored as metric (kg, cm) — conversion happens at display time.
class UnitPreference {
  static const _key = 'unit_system';

  // Unit system variants
  static UnitSystem _current = UnitSystem.metric;
  static UnitSystem get current => _current;
  static bool get isImperial => _current == UnitSystem.imperial;

  /// Load from storage (call once at app startup)
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == UnitSystem.imperial.name) {
      _current = UnitSystem.imperial;
    } else {
      _current = UnitSystem.metric;
    }
  }

  /// Toggle and persist
  static Future<void> toggle() async {
    _current = isImperial ? UnitSystem.metric : UnitSystem.imperial;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _current.name);
  }

  /// Set explicitly
  static Future<void> set(UnitSystem system) async {
    _current = system;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, system.name);
  }

  // ══════════════════════════════════════════════
  // Weight conversions
  // ══════════════════════════════════════════════

  /// Display weight from stored kg value
  static String formatWeight(double kg, {int decimals = 1}) {
    if (isImperial) {
      final lbs = kg * 2.20462;
      return '${lbs.toStringAsFixed(decimals)} lbs';
    }
    return '${kg.toStringAsFixed(decimals)} kg';
  }

  /// Convert display value back to kg for storage
  static double toKg(double displayValue) {
    if (isImperial) return displayValue / 2.20462;
    return displayValue;
  }

  /// Convert stored kg to display unit
  static double fromKg(double kg) {
    if (isImperial) return kg * 2.20462;
    return kg;
  }

  static String get weightUnit => isImperial ? 'lbs' : 'kg';
  static double get weightMin => isImperial ? 88.0 : 40.0;
  static double get weightMax => isImperial ? 352.0 : 160.0;
  static double get weightStep => isImperial ? 0.5 : 0.5;

  // ══════════════════════════════════════════════
  // Height conversions
  // ══════════════════════════════════════════════

  /// Display height from stored cm value
  static String formatHeight(double cm) {
    if (isImperial) {
      final totalInches = cm / 2.54;
      final feet = totalInches ~/ 12;
      final inches = (totalInches % 12).round();
      return "$feet′${inches.toString().padLeft(2, '0')}″";
    }
    return '${cm.round()} cm';
  }

  /// Convert display (feet decimal) back to cm
  static double toCm(double displayValue) {
    if (isImperial) return displayValue * 2.54; // inches to cm
    return displayValue;
  }

  /// Convert stored cm to display inches (for slider in imperial)
  static double fromCm(double cm) {
    if (isImperial) return cm / 2.54; // cm to inches
    return cm;
  }

  static String get heightUnit => isImperial ? 'in' : 'cm';
  static double get heightMinCm => isImperial ? 55 * 2.54 : 140.0;  // 4'7" 
  static double get heightMaxCm => isImperial ? 87 * 2.54 : 220.0;  // 7'3"

  // ══════════════════════════════════════════════
  // Formatted display helpers
  // ══════════════════════════════════════════════

  static String get systemLabel => isImperial ? 'Imperial' : 'Metric';
  static String get systemFlag  => isImperial ? '🇺🇸' : '🌍';
}

enum UnitSystem { metric, imperial }
