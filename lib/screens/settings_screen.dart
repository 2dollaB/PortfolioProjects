import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../main.dart';
import '../services/audio_cue_service.dart';
import '../services/health_sync_service.dart';
import '../services/notification_service.dart';
import '../services/unit_preference.dart';

/// Settings screen — 6.2 units, 6.3 health sync, 6.4 notifications
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Units (6.2)
  UnitSystem _unitSystem = UnitPreference.current;

  // Notifications (6.4)
  bool _reminderEnabled = false;
  int _reminderHour   = 7;
  int _reminderMin    = 0;

  // Health sync (6.3)
  bool _healthPermGranted = false;
  bool _healthChecking = false;

  // 2.6 — Audio cues
  bool _audioCuesEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final reminderEnabled = await NotificationService.isReminderEnabled();
    final reminderTime    = await NotificationService.reminderTime();
    final healthGranted   = await HealthSyncService.hasPermissions();
    if (mounted) {
      setState(() {
        _unitSystem     = UnitPreference.current;
        _reminderEnabled = reminderEnabled;
        _reminderHour   = reminderTime.hour;
        _reminderMin    = reminderTime.minute;
        _healthPermGranted = healthGranted;
        _audioCuesEnabled = AudioCueService.isEnabled;
      });
    }
  }

  // ══════════════════════════════════════════════
  // Actions
  // ══════════════════════════════════════════════

  Future<void> _toggleUnit(UnitSystem system) async {
    HapticFeedback.selectionClick();
    await UnitPreference.set(system);
    setState(() => _unitSystem = system);
  }

  Future<void> _toggleReminder(bool value) async {
    HapticFeedback.selectionClick();
    if (value) {
      await NotificationService.requestPermission();
      await NotificationService.scheduleDailyReminder(
        TimeOfDay(hour: _reminderHour, minute: _reminderMin),
      );
    } else {
      await NotificationService.cancelDailyReminder();
    }
    setState(() => _reminderEnabled = value);
  }

  Future<void> _pickReminderTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMin),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppTheme.accent,
            surface: AppTheme.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (result != null) {
      setState(() {
        _reminderHour = result.hour;
        _reminderMin  = result.minute;
      });
      if (_reminderEnabled) {
        await NotificationService.scheduleDailyReminder(
          TimeOfDay(hour: result.hour, minute: result.minute),
        );
      } else {
        await NotificationService.saveReminderTime(
          TimeOfDay(hour: result.hour, minute: result.minute),
        );
      }
    }
  }

  Future<void> _connectHealth() async {
    setState(() => _healthChecking = true);
    HapticFeedback.mediumImpact();
    final granted = await HealthSyncService.requestPermissions();
    if (mounted) {
      setState(() {
        _healthPermGranted = granted;
        _healthChecking = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(granted
              ? '✓ Health access connected!'
              : 'Permission denied — enable in Settings'),
          backgroundColor: granted ? AppTheme.success : AppTheme.danger,
        ),
      );
    }
  }

  String get _reminderTimeLabel {
    final h = _reminderHour.toString().padLeft(2, '0');
    final m = _reminderMin.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings',
            style: AppTheme.heading(fontSize: 20, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── 6.2 Units ─────────────────────────────
          _sectionHeader('UNITS', Icons.straighten),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glowCard(color: AppTheme.accent),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Measurement System',
                    style: AppTheme.body(
                        fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 4),
                Text('Data always stored as metric — only changes how it\'s displayed.',
                    style: AppTheme.body(fontSize: 12, color: AppTheme.textMuted)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _unitChip(
                      label: '🌍 Metric',
                      subtitle: 'kg, cm',
                      selected: _unitSystem == UnitSystem.metric,
                      onTap: () => _toggleUnit(UnitSystem.metric),
                    ),
                    const SizedBox(width: 12),
                    _unitChip(
                      label: '🇺🇸 Imperial',
                      subtitle: 'lbs, ft·in',
                      selected: _unitSystem == UnitSystem.imperial,
                      onTap: () => _toggleUnit(UnitSystem.imperial),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 2.6 Audio Cues ─────────────────────
          _sectionHeader('AUDIO CUES', Icons.volume_up_rounded),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glowCard(color: const Color(0xFF8B5CF6)),
            child: Row(
              children: [
                const Icon(Icons.record_voice_over, color: Color(0xFF8B5CF6), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Zone Announcements',
                          style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                      Text('Speak zone changes during workout',
                          style: AppTheme.body(fontSize: 11, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                Switch(
                  value: _audioCuesEnabled,
                  activeColor: const Color(0xFF8B5CF6),
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    AudioCueService.setEnabled(v);
                    setState(() => _audioCuesEnabled = v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 6.3 Health Sync ───────────────────────
          _sectionHeader(
            Platform.isIOS ? 'APPLE HEALTH' : 'HEALTH CONNECT',
            Platform.isIOS ? Icons.favorite : Icons.monitor_heart,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glowCard(
                color: _healthPermGranted ? AppTheme.success : AppTheme.textMuted),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (Platform.isIOS
                            ? const Color(0xFFFF2D55)
                            : const Color(0xFF4CAF50))
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Platform.isIOS ? Icons.favorite : Icons.health_and_safety,
                        size: 24,
                        color: Platform.isIOS
                            ? const Color(0xFFFF2D55)
                            : const Color(0xFF4CAF50),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Platform.isIOS
                                ? 'Apple Health'
                                : 'Google Health Connect',
                            style: AppTheme.body(
                                fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _healthPermGranted
                                ? 'Connected — workouts sync automatically'
                                : 'Tap to connect and sync workouts',
                            style: AppTheme.body(
                                fontSize: 12,
                                color: _healthPermGranted
                                    ? AppTheme.success
                                    : AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    if (_healthPermGranted)
                      Icon(Icons.check_circle, color: AppTheme.success, size: 22)
                    else
                      _healthChecking
                          ? SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  color: AppTheme.accent, strokeWidth: 2))
                          : TextButton(
                              onPressed: _connectHealth,
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.accent,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                backgroundColor: AppTheme.accent.withValues(alpha: 0.1),
                              ),
                              child: Text('Connect',
                                  style: AppTheme.mono(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.accent)),
                            ),
                  ],
                ),
                if (_healthPermGranted) ...[
                  const SizedBox(height: 14),
                  Divider(color: AppTheme.surfaceLight),
                  const SizedBox(height: 10),
                  _healthInfoRow(Icons.fitness_center, 'Workouts', 'Writes session + calories'),
                  const SizedBox(height: 6),
                  _healthInfoRow(Icons.favorite_border, 'Heart Rate', 'Writes avg HR per workout'),
                  const SizedBox(height: 6),
                  _healthInfoRow(Icons.bedtime, 'Resting HR', 'Reads from Health for profile'),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 6.4 Notifications ─────────────────────
          _sectionHeader('NOTIFICATIONS', Icons.notifications_none),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glowCard(color: AppTheme.accent),
            child: Column(
              children: [
                // Daily reminder toggle
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.alarm, size: 22, color: Color(0xFFF97316)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Daily Reminder',
                              style: AppTheme.body(
                                  fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                          Text('Get a daily nudge at your chosen time',
                              style: AppTheme.body(fontSize: 12, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _reminderEnabled,
                      onChanged: _toggleReminder,
                      activeThumbColor: AppTheme.accent,
                      inactiveTrackColor: AppTheme.surfaceLight,
                    ),
                  ],
                ),

                // Time picker (visible only if enabled)
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: _reminderEnabled
                      ? Column(
                          children: [
                            const SizedBox(height: 14),
                            Divider(color: AppTheme.surfaceLight),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: _pickReminderTime,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.background,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.access_time,
                                        size: 18, color: AppTheme.accent),
                                    const SizedBox(width: 10),
                                    Text('Reminder Time',
                                        style: AppTheme.body(
                                            fontSize: 14, color: AppTheme.textSecondary)),
                                    const Spacer(),
                                    Text(_reminderTimeLabel,
                                        style: AppTheme.heading(
                                            fontSize: 18,
                                            color: AppTheme.accent,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 6),
                                    Icon(Icons.chevron_right,
                                        size: 18, color: AppTheme.textMuted),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 14),
                Divider(color: AppTheme.surfaceLight),
                const SizedBox(height: 10),

                // Streak notifications
                _notifRow(
                  Icons.local_fire_department,
                  const Color(0xFFEF4444),
                  'Streak Milestones',
                  'Get celebrated at 3, 7, 14 & 30 days',
                  true, // always on — fired by app on streak check
                  null,
                ),
                const SizedBox(height: 8),
                _notifRow(
                  Icons.self_improvement,
                  const Color(0xFF6C63FF),
                  'Recovery Reminders',
                  'Sent 12h after each completed workout',
                  true, // always on
                  null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 9.4 Theme Toggle ──────────────────────
          _sectionHeader('APPEARANCE', Icons.palette_outlined),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.boldCard(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme',
                    style: AppTheme.body(
                        fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 4),
                Text('Choose your preferred appearance',
                    style: AppTheme.body(fontSize: 12, color: AppTheme.textMuted)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _themeChip('🌙', 'Dark', ThemeMode.dark),
                    const SizedBox(width: 10),
                    _themeChip('☀️', 'Light', ThemeMode.light),
                    const SizedBox(width: 10),
                    _themeChip('📱', 'System', ThemeMode.system),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── About ──────────────────────────────────
          _sectionHeader('ABOUT', Icons.info_outline),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.surfaceLight),
            ),
            child: Column(
              children: [
                _aboutRow('Version', '1.0.0'),
                const SizedBox(height: 8),
                _aboutRow('Build', 'Release'),
                const SizedBox(height: 8),
                _aboutRow('HR Algorithm', 'Tanaka / Gulati / Karvonen'),
                const SizedBox(height: 8),
                _aboutRow('Training Load', 'Bannister TRIMP'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textMuted),
        const SizedBox(width: 6),
        Text(title,
            style: AppTheme.mono(
              fontSize: 11, letterSpacing: 2,
              color: AppTheme.textMuted, fontWeight: FontWeight.w600,
            )),
      ],
    );
  }

  Widget _unitChip({
    required String label,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: [
                      AppTheme.accent.withValues(alpha: 0.2),
                      AppTheme.accent.withValues(alpha: 0.06),
                    ],
                  )
                : null,
            color: selected ? null : AppTheme.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.accent : AppTheme.surfaceLight,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(label,
                  style: AppTheme.body(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppTheme.textSecondary,
                  )),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: AppTheme.mono(
                    fontSize: 11,
                    color: selected ? AppTheme.accent : AppTheme.textMuted,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _healthInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textMuted),
        const SizedBox(width: 8),
        Text(label, style: AppTheme.body(fontSize: 13, color: AppTheme.textSecondary)),
        const Spacer(),
        Text(value, style: AppTheme.mono(fontSize: 11, color: AppTheme.textMuted)),
      ],
    );
  }

  Widget _notifRow(IconData icon, Color color, String title,
      String subtitle, bool enabled, ValueChanged<bool>? onChanged) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AppTheme.body(
                      fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
              Text(subtitle,
                  style: AppTheme.body(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
        ),
        if (onChanged != null)
          Switch(value: enabled, onChanged: onChanged, activeThumbColor: color)
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('ON',
                style: AppTheme.mono(
                    fontSize: 10, color: AppTheme.success, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }

  Widget _aboutRow(String key, String value) {
    return Row(
      children: [
        Text(key, style: AppTheme.body(fontSize: 13, color: AppTheme.textMuted)),
        const Spacer(),
        Text(value,
            style: AppTheme.mono(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _themeChip(String emoji, String label, ThemeMode mode) {
    final current = Theme.of(context).brightness == Brightness.dark
        ? ThemeMode.dark : ThemeMode.light;
    // Approximate — read actual from app state  
    final sel = mode == current;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          final state = context.findAncestorStateOfType<BeatSyncAppState>();
          state?.setThemeMode(mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? AppTheme.accent.withValues(alpha: 0.12) : AppTheme.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: sel ? AppTheme.accent : AppTheme.surfaceLight,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 4),
              Text(label,
                  style: AppTheme.mono(fontSize: 10, fontWeight: FontWeight.w600,
                      color: sel ? AppTheme.accent : AppTheme.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
