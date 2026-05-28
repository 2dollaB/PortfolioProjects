/// BeatSync spacing tokens — 8pt grid.
/// Reference these instead of hardcoding paddings/gaps.
class AppSpacing {
  AppSpacing._();

  static const double micro = 4;   // icon to label
  static const double xs    = 8;   // tight, internal padding
  static const double sm    = 12;  // small
  static const double md    = 16;  // base — most card padding
  static const double lg    = 24;  // section gap
  static const double xl    = 32;  // screen margin, major section break
  static const double xxl   = 48;  // hero spacing
}

/// Border radius tokens.
class AppRadius {
  AppRadius._();

  static const double sm   = 8;
  static const double md   = 12;  // buttons, chips
  static const double lg   = 16;  // cards
  static const double xl   = 20;  // hero cards, modals
  static const double pill = 999;
}

/// Elevation tokens (used as blur radius for shadows in dark mode).
class AppElevation {
  AppElevation._();

  static const double none = 0;
  static const double sm   = 4;
  static const double md   = 12;
  static const double lg   = 24;
}
