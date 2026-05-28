import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/hr_zones.dart';
import '../config/theme.dart';
import '../models/user_profile.dart';
import '../services/mock_data.dart';
import '../widgets/beat_button.dart';
import '../widgets/bpm_display.dart';
import '../widgets/zone_bar.dart';
import 'workout_summary_screen.dart';

/// Immersive single-athlete workout view — giant BPM, ring, zone bar, live stats.
/// Mock-data driven for the prototype: BPM wobbles around a realistic curve
/// so the live UI looks alive even without a real BLE strap.
class WorkoutScreen extends StatefulWidget {
  final UserProfile profile;
  final bool inGroupSession;

  const WorkoutScreen({
    super.key,
    required this.profile,
    this.inGroupSession = false,
  });

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  Timer? _tick;
  final _stopwatch = Stopwatch();
  int _bpm = 78;
  int _maxBpm = 78;
  final List<int> _bpmHistory = [];
  bool _paused = false;
  final _rng = math.Random();
  double _kcal = 0;
  double _trimp = 0;

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    _tick = Timer.periodic(const Duration(milliseconds: 800), (_) => _step());
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _step() {
    if (_paused || !mounted) return;
    setState(() {
      // Target curve: ramps up during the first minute, oscillates 130-170 after.
      final elapsedSec = _stopwatch.elapsed.inSeconds.toDouble();
      final base = elapsedSec < 60
          ? 78 + (elapsedSec / 60.0) * 70
          : 145 + math.sin(elapsedSec / 18) * 22;
      final noise = (_rng.nextDouble() - 0.5) * 6;
      final next = (base + noise).round().clamp(60, 200);
      _bpm = next;
      _maxBpm = math.max(_maxBpm, _bpm);
      _bpmHistory.add(_bpm);
      if (_bpmHistory.length > 120) _bpmHistory.removeAt(0);

      final hrMax = widget.profile.hrMax;
      final pct = (_bpm / hrMax).clamp(0.0, 1.5);
      _kcal += 0.18 * pct * widget.profile.weightKg / 60;
      _trimp += pct * pct * widget.profile.trimpGenderFactor * 0.05;
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _stopwatch.stop();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  Future<void> _endWorkout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkBgSecondary,
        title: const Text('End workout?'),
        content: Text(
          "We'll save your session and show you the summary.",
          style: AppTheme.bodyLarge(color: AppColors.darkTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.brandRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WorkoutSummaryScreen(
            durationMin: _stopwatch.elapsed.inMinutes,
            avgBpm: _bpmHistory.isEmpty
                ? _bpm
                : _bpmHistory.reduce((a, b) => a + b) ~/ _bpmHistory.length,
            maxBpm: _maxBpm,
            calories: _kcal.round(),
            trimp: _trimp.round(),
            profile: widget.profile,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hrMax = widget.profile.hrMax;
    final zone = HrZones.fromBpm(_bpm, hrMax);
    final zoneColor = AppColors.zoneColor(zone == 0 ? 1 : zone);

    return Scaffold(
      backgroundColor: AppColors.darkBgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Live indicator + close
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _endWorkout,
                  ),
                  if (widget.inGroupSession) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brandRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: AppColors.brandRed.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.brandRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'LIVE · Studio session',
                            style: AppTheme.micro(color: AppColors.brandRed)
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.micro,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.darkBgSecondary,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.darkBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bluetooth_connected_rounded,
                            size: 14, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text(
                          'H10 · ${(85 + _rng.nextInt(15))}%',
                          style: AppTheme.caption(color: AppColors.success)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // BIG BPM
            BpmDisplay(bpm: _bpm, hrMax: hrMax, size: 280),

            const SizedBox(height: AppSpacing.lg),

            // Zone bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: ZoneBar(activeZone: zone == 0 ? 1 : zone),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Stats row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: _LiveStat(
                      label: 'Duration',
                      value: _formatDuration(_stopwatch.elapsed),
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: AppColors.darkBorder,
                  ),
                  Expanded(
                    child: _LiveStat(
                      label: 'Calories',
                      value: _kcal.round().toString(),
                      unit: 'kcal',
                      color: zoneColor,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: AppColors.darkBorder,
                  ),
                  Expanded(
                    child: _LiveStat(
                      label: 'TRIMP',
                      value: _trimp.toStringAsFixed(0),
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Leaderboard strip — only in group sessions
            if (widget.inGroupSession) ...[
              _LeaderboardStrip(myBpm: _bpm, myRank: 4),
              const SizedBox(height: AppSpacing.sm),
            ],

            // Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.lg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: BeatSecondaryButton(
                      label: _paused ? 'Resume' : 'Pause',
                      icon: _paused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      onPressed: () => setState(() {
                        _paused = !_paused;
                        if (_paused) {
                          _stopwatch.stop();
                        } else {
                          _stopwatch.start();
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: BeatPrimaryButton(
                      label: widget.inGroupSession ? 'Leave' : 'End',
                      icon: Icons.stop_rounded,
                      onPressed: _endWorkout,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveStat extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color color;

  const _LiveStat({
    required this.label,
    required this.value,
    required this.color,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: AppTheme.micro().copyWith(letterSpacing: 1.4),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: AppTheme.statNumber(fontSize: 24, color: color)),
            if (unit != null) ...[
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(unit!, style: AppTheme.caption()),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Compact leaderboard shown at the bottom of an athlete's group session.
/// Top-3 names with their BPM + the athlete's own position highlighted.
class _LeaderboardStrip extends StatelessWidget {
  final int myBpm;
  final int myRank;
  const _LeaderboardStrip({required this.myBpm, required this.myRank});

  @override
  Widget build(BuildContext context) {
    final top3 = MockData.liveSession.take(3).toList();
    final totalAthletes = MockData.liveSession.length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'LEADERBOARD',
                style: AppTheme.micro().copyWith(letterSpacing: 1.4),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brandRed.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.brandRed.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'YOU',
                      style: AppTheme.micro(color: AppColors.brandRed)
                          .copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '#$myRank',
                      style: AppTheme.statNumber(
                        fontSize: 14,
                        color: AppColors.brandRed,
                        weight: FontWeight.w800,
                      ).copyWith(height: 1.0),
                    ),
                    Text(
                      '/$totalAthletes',
                      style: AppTheme.caption(color: AppColors.brandRed),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (int i = 0; i < top3.length; i++) ...[
                Expanded(
                  child: _LeaderboardSlot(
                    rank: i + 1,
                    name: top3[i].name,
                    bpm: top3[i].bpm,
                  ),
                ),
                if (i < top3.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaderboardSlot extends StatelessWidget {
  final int rank;
  final String name;
  final int bpm;
  const _LeaderboardSlot({
    required this.rank,
    required this.name,
    required this.bpm,
  });

  Color get _rankColor {
    switch (rank) {
      case 1:
        return AppColors.warning; // gold-ish
      case 2:
        return AppColors.darkTextPrimary;
      case 3:
        return AppColors.zone4;
      default:
        return AppColors.darkTextSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.darkBgTertiary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _rankColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: _rankColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: AppTheme.statNumber(
                fontSize: 12,
                color: _rankColor,
                weight: FontWeight.w800,
              ).copyWith(height: 1.0),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name.split(' ').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.caption(color: AppColors.darkTextPrimary)
                      .copyWith(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                Text(
                  '$bpm bpm',
                  style: AppTheme.micro(color: _rankColor)
                      .copyWith(fontWeight: FontWeight.w700, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
