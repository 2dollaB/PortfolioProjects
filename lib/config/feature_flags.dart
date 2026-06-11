/// Single switch board for in-flight features.
/// Flip a flag to surface (or hide) something across the whole app.
class FeatureFlags {
  FeatureFlags._();

  // ── DEMO MODE ─────────────────────────────────
  /// When true, the app boots into prototype/demo flow with mock data
  /// — splash → role select → login → home. Skip onboarding, skip BLE,
  /// skip real storage. Designed for client presentations.
  static const bool prototypeMode = false;

  // ── MVP gating (post-launch features hidden until ready) ──
  static const bool trends           = false;  // ACWR, weekly TRIMP, zone trends
  static const bool hrv              = false;  // RMSSD/SDNN display
  static const bool audioCues        = false;  // TTS announcements
  static const bool healthSync       = false;  // Apple Health / Health Connect
  static const bool rpeAndMood       = false;  // RPE 1-10 + mood logging
  static const bool activityCalendar = false;  // heatmap
  static const bool backupImport     = false;  // JSON backup/restore
  static const bool personalRecords  = false;

  // ── Paid features (free MVP — flip on once a paying studio signs) ──
  static const bool paywall = false;
}
