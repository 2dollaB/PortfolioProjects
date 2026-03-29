import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/hr_zones.dart';
import '../config/theme.dart';
import '../services/tv_server.dart';

/// 5.1 — Trainer's live monitoring screen
/// Shows all connected athletes, sorted by HR%, with zone badges.
/// 5.2 — Interval timer controls built in.
class TrainerMonitorScreen extends StatefulWidget {
  final TvServer tvServer;

  const TrainerMonitorScreen({super.key, required this.tvServer});

  @override
  State<TrainerMonitorScreen> createState() => _TrainerMonitorScreenState();
}

class _TrainerMonitorScreenState extends State<TrainerMonitorScreen>
    with TickerProviderStateMixin {
  // Rebuild ticker every second
  Timer? _ticker;
  // Interval picker state
  int _workSeconds = 40;
  int _restSeconds = 20;

  // Quick interval presets [work, rest] in seconds
  static const _presets = [
    ('20/10', 20, 10),
    ('30/15', 30, 15),
    ('40/20', 40, 20),
    ('45/15', 45, 15),
    ('60/30', 60, 30),
    ('90/30', 90, 30),
  ];

  @override
  void initState() {
    super.initState();
    widget.tvServer.onStateChanged = () {
      if (mounted) setState(() {});
    };
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    widget.tvServer.onStateChanged = null;
    super.dispose();
  }

  String _fmt(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  // ── Interval Control ──────────────────────────

  void _sendWork() {
    HapticFeedback.mediumImpact();
    widget.tvServer.startWorkInterval(seconds: _workSeconds, label: 'WORK');
  }

  void _sendRest() {
    HapticFeedback.lightImpact();
    widget.tvServer.startRestInterval(seconds: _restSeconds, label: 'REST');
  }

  void _cancelInterval() {
    widget.tvServer.cancelInterval();
  }

  void _showPresetPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Interval Presets',
                style: AppTheme.heading(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Work / Rest in seconds',
                style: AppTheme.body(fontSize: 13, color: AppTheme.textMuted)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: _presets.map((p) {
                final (label, w, r) = p;
                final selected = _workSeconds == w && _restSeconds == r;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _workSeconds = w;
                      _restSeconds = r;
                    });
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: selected
                          ? LinearGradient(
                              colors: [AppTheme.accent, AppTheme.accentLight.withValues(alpha: 0.7)],
                            )
                          : null,
                      color: selected ? null : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(label,
                        style: AppTheme.mono(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : AppTheme.textSecondary,
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            // Custom stepper
            Row(
              children: [
                Expanded(child: _buildSecondStepper('WORK', _workSeconds, (v) => setState(() => _workSeconds = v), 10, 180, 5)),
                const SizedBox(width: 12),
                Expanded(child: _buildSecondStepper('REST', _restSeconds, (v) => setState(() => _restSeconds = v), 5, 120, 5)),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondStepper(String label, int value, void Function(int) onChanged, int min, int max, int step) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            onPressed: value - step >= min ? () => onChanged(value - step) : null,
            color: AppTheme.textMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          Expanded(
            child: Column(
              children: [
                Text('$value s', style: AppTheme.heading(fontSize: 18, color: Colors.white)),
                Text(label, style: AppTheme.mono(fontSize: 9, color: AppTheme.textMuted, letterSpacing: 1)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: value + step <= max ? () => onChanged(value + step) : null,
            color: AppTheme.textMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = widget.tvServer.userStates.values.toList()
      ..sort((a, b) {
        final pA = a.hrMax > 0 ? a.bpm / a.hrMax : 0;
        final pB = b.hrMax > 0 ? b.bpm / b.hrMax : 0;
        return pB.compareTo(pA);
      });

    final phase = widget.tvServer.currentPhase;
    final secsLeft = widget.tvServer.intervalSecondsLeft;
    final sessionSecs = widget.tvServer.sessionSeconds;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trainer Monitor',
                style: AppTheme.heading(fontSize: 18, fontWeight: FontWeight.w600)),
            Text(widget.tvServer.sessionName,
                style: AppTheme.mono(fontSize: 11, color: AppTheme.textMuted, letterSpacing: 1)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_fmt(sessionSecs),
                    style: AppTheme.heading(fontSize: 20, color: AppTheme.accent)),
                Text('session', style: AppTheme.mono(fontSize: 9, color: AppTheme.textMuted)),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Interval Controls (5.2) ──────────────────
          _buildIntervalControls(phase, secsLeft),

          // ── Athletes List (5.1) ──────────────────────
          Expanded(
            child: users.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: users.length,
                    itemBuilder: (ctx, i) => _buildAthleteRow(users[i], i),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Interval Controls Panel ──

  Widget _buildIntervalControls(IntervalPhase phase, int secsLeft) {
    final isActive = phase != IntervalPhase.idle;
    final phaseColor = phase == IntervalPhase.work
        ? AppTheme.success
        : phase == IntervalPhase.rest
            ? const Color(0xFF6C63FF)
            : AppTheme.textMuted;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.surface,
            AppTheme.surface.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isActive
              ? phaseColor.withValues(alpha: 0.4)
              : AppTheme.surfaceLight,
        ),
      ),
      child: Column(
        children: [
          // Active phase display
          if (isActive) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: phaseColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.tvServer.intervalLabel,
                    style: AppTheme.mono(
                      fontSize: 14, letterSpacing: 2,
                      color: phaseColor, fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _fmt(secsLeft),
                  style: AppTheme.heading(
                    fontSize: 32, color: phaseColor, fontWeight: FontWeight.w200,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Buttons row
          Row(
            children: [
              // Preset picker
              OutlinedButton.icon(
                onPressed: _showPresetPicker,
                icon: Icon(Icons.tune, size: 16, color: AppTheme.accent),
                label: Text(
                  '${_workSeconds}s / ${_restSeconds}s',
                  style: AppTheme.mono(fontSize: 12, color: AppTheme.accent, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const Spacer(),
              // REST button
              GestureDetector(
                onTap: _sendRest,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pause_circle_outline, size: 16, color: Color(0xFF6C63FF)),
                      const SizedBox(width: 6),
                      Text('REST', style: AppTheme.mono(
                        fontSize: 13, color: const Color(0xFF6C63FF), fontWeight: FontWeight.w700,
                      )),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // WORK button
              GestureDetector(
                onTap: _sendWork,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.success, AppTheme.success.withValues(alpha: 0.7)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: AppTheme.success.withValues(alpha: 0.3), blurRadius: 12),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text('GO', style: AppTheme.mono(
                        fontSize: 13, color: Colors.white, fontWeight: FontWeight.w800,
                      )),
                    ],
                  ),
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _cancelInterval,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.stop_rounded, size: 16, color: AppTheme.danger),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Athlete Row ──

  Widget _buildAthleteRow(UserHrState u, int rank) {
    final zoneColor = HrZones.colors[u.zone] ?? Colors.grey;
    final pct = u.hrMax > 0 ? (u.bpm / u.hrMax * 100).round() : 0;
    final rankLabel = rank == 0 ? '🥇' : rank == 1 ? '🥈' : rank == 2 ? '🥉' : '#${rank + 1}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: zoneColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: zoneColor.withValues(alpha: 0.06),
            blurRadius: 12, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 32,
            child: Text(rankLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 10),

          // Name + zone bar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.name,
                    style: AppTheme.body(
                      fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white,
                    )),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    height: 4,
                    child: LinearProgressIndicator(
                      value: (pct / 100).clamp(0.0, 1.0),
                      backgroundColor: AppTheme.surfaceLight,
                      valueColor: AlwaysStoppedAnimation(zoneColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Zone badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: zoneColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Z${u.zone}',
              style: AppTheme.mono(
                fontSize: 10, color: zoneColor, fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // BPM + %
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${u.bpm}',
                  style: AppTheme.heading(
                    fontSize: 26, color: zoneColor, fontWeight: FontWeight.w200,
                  )),
              Text('$pct%',
                  style: AppTheme.mono(
                    fontSize: 10, color: AppTheme.textMuted,
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group_outlined, size: 56, color: AppTheme.textMuted.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('No athletes connected',
              style: AppTheme.heading(fontSize: 18, color: AppTheme.textSecondary)),
          const SizedBox(height: 6),
          Text('Athletes will appear once they start a workout',
              style: AppTheme.body(fontSize: 13, color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}
