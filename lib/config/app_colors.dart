import 'package:flutter/material.dart';

/// BeatSync color tokens — single source of truth.
/// Two palettes: dark (primary) and light. Semantic names — never reference hex elsewhere.
///
/// Screens read the **semantic getters** ([bgPrimary], [textPrimary], …) which
/// resolve against [brightness]. The app sets [brightness] whenever the theme
/// mode changes (see `main.dart`), so flipping light/dark relights every screen.
/// The raw `dark*`/`light*` palettes below stay explicit for `theme.dart`.
class AppColors {
  AppColors._();

  /// Current UI brightness — flipped by `BeatSyncAppState.setThemeMode`. The
  /// semantic getters below read this; a theme change triggers an app rebuild
  /// so the new values are picked up.
  static Brightness brightness = Brightness.dark;

  static bool get _dark => brightness == Brightness.dark;

  // ── SEMANTIC (mode-aware) ──────────────────────
  static Color get bgPrimary    => _dark ? darkBgPrimary : lightBgPrimary;
  static Color get bgSecondary  => _dark ? darkBgSecondary : lightBgSecondary;
  static Color get bgTertiary   => _dark ? darkBgTertiary : lightBgTertiary;
  static Color get border       => _dark ? darkBorder : lightBorder;
  static Color get textPrimary  => _dark ? darkTextPrimary : lightTextPrimary;
  static Color get textSecondary => _dark ? darkTextSecondary : lightTextSecondary;
  static Color get textTertiary => _dark ? darkTextTertiary : lightTextTertiary;

  // ── DARK MODE (PRIMARY) ────────────────────────
  static const Color darkBgPrimary    = Color(0xFF0D0D0F);
  static const Color darkBgSecondary  = Color(0xFF16161A);
  static const Color darkBgTertiary   = Color(0xFF1E1E24);
  static const Color darkBorder       = Color(0xFF2A2A35);
  static const Color darkTextPrimary  = Color(0xFFF0F0F5);
  static const Color darkTextSecondary = Color(0xFF8A8A9A);
  static const Color darkTextTertiary = Color(0xFF55556A);

  // ── LIGHT MODE ─────────────────────────────────
  static const Color lightBgPrimary    = Color(0xFFF7F7FA);
  static const Color lightBgSecondary  = Color(0xFFFFFFFF);
  static const Color lightBgTertiary   = Color(0xFFEDEDF2);
  static const Color lightBorder       = Color(0xFFDDDDE8);
  static const Color lightTextPrimary  = Color(0xFF0D0D0F);
  static const Color lightTextSecondary = Color(0xFF5A5A70);
  static const Color lightTextTertiary = Color(0xFF9999B0);

  // ── BRAND ──────────────────────────────────────
  static const Color brandRed         = Color(0xFFE8003D);  // primary CTA, heartbeat
  static const Color brandRedLight    = Color(0xFFCC0033);  // light-mode variant
  static const Color brandGlow        = Color(0x33E8003D);  // rgba(232,0,61,0.2) glow halo

  // ── SEMANTIC ───────────────────────────────────
  static const Color success = Color(0xFF00C896);  // safe / Z1-2 / completed
  static const Color warning = Color(0xFFF5A623);  // moderate / Z3
  static const Color danger  = Color(0xFFFF4757);  // alert / Z4-5

  // ── HR ZONES (consistent across dark + light) ──
  static const Color zone1 = Color(0xFF4FC3F7);  // recovery — light blue
  static const Color zone2 = Color(0xFF00C896);  // aerobic base — green
  static const Color zone3 = Color(0xFFF5A623);  // tempo — amber
  static const Color zone4 = Color(0xFFFF6B35);  // threshold — orange
  static const Color zone5 = Color(0xFFE8003D);  // max effort — brand red
  static const Color zoneRest = Color(0xFF55556A);  // resting

  static const Map<int, Color> zoneMap = {
    0: zoneRest,
    1: zone1,
    2: zone2,
    3: zone3,
    4: zone4,
    5: zone5,
  };

  static Color zoneColor(int zone) => zoneMap[zone] ?? zoneRest;
}
