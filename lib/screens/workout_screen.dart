import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/hr_zones.dart';
import '../config/theme.dart';
import '../models/cloud_session.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/session_repository.dart';
import '../services/workout_repository.dart';
import '../widgets/beat_button.dart';
import '../widgets/bpm_display.dart';
import '../widgets/mobile_frame.dart';
import '../widgets/workout_type_sheet.dart';
import '../widgets/zone_bar.dart';
import 'tv_host_screen.dart';
import 'workout_summary_screen.dart';

/// Immersive single-athlete workout view â€” giant BPM, ring, zone bar, live stats.
/// Mock-data driven for the prototype: BPM wobbles around a realistic curve
/// so the live UI looks alive even without a real BLE strap.
class WorkoutScreen extends StatefulWidget {
  final UserProfile profile;
  final bool inGroupSession;

  /// Production group session — when set (and signed in), the workout
  /// publishes the athlete's HR to the session's live board ~1/sec.
  final CloudSession? session;

  /// Picked from the WorkoutTypeSheet before launch. Saved with the workout
  /// so history can filter by type.
  final WorkoutType? workoutType;

  const WorkoutScreen({
    super.key,
    required this.profile,
    this.inGroupSession = false,
    this.session,
    this.workoutType,
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
    _publishHr();
  }

  int get _avgBpm => _bpmHistory.isEmpty
      ? _bpm
      : _bpmHistory.reduce((a, b) => a + b) ~/ _bpmHistory.length;

  DateTime? _lastHrPush;

  /// ~1/sec heartbeat to the group session's live board. Failures (e.g. the
  /// trainer just ended the session) are non-fatal — the personal workout
  /// keeps running.
  void _publishHr() {
    final session = widget.session;
    final uid = AuthService.currentUid;
    if (session == null || uid == null) return;
    final now = DateTime.now();
    if (_lastHrPush != null &&
        now.difference(_lastHrPush!) < const Duration(seconds: 1)) {
      return;
    }
    _lastHrPush = now;
    final hrMax = widget.profile.hrMax;
    SessionRepository.writeHr(
      sessionId: session.id,
      uid: uid,
      bpm: _bpm,
      avgBpm: _avgBpm,
      zone: HrZones.fromBpm(_bpm, hrMax).clamp(0, 5),
      hrMax: hrMax,
    ).catchError((_) {});
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
      final session = widget.session;
      final uid = AuthService.currentUid;
      if (session != null && uid != null) {
        // Drop off the live board; fails harmlessly if the session ended.
        unawaited(SessionRepository.removeHr(sessionId: session.id, uid: uid)
            .catchError((_) {}));
      }
      unawaited(_persistWorkout());
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WorkoutSummaryScreen(
            durationMin: _stopwatch.elapsed.inMinutes,
            avgBpm: _avgBpm,
            maxBpm: _maxBpm,
            calories: _kcal.round(),
            trimp: _trimp.round(),
            profile: widget.profile,
            workoutType: widget.workoutType,
          ),
        ),
      );
    }
  }

  /// Persist this session's summary to Firestore when signed in (production).
  /// Fire-and-forget: navigation isn't blocked and Firestore's offline queue
  /// handles transient failures.
  Future<void> _persistWorkout() async {
    final uid = AuthService.currentUid;
    if (uid == null) return; // prototype / not signed in
    final hrMax = widget.profile.hrMax;
    final avg = _avgBpm;
    // Zone distribution (% of samples per zone 0-5) + dominant training zone.
    final counts = List<int>.filled(6, 0);
    for (final b in _bpmHistory) {
      counts[HrZones.fromBpm(b, hrMax).clamp(0, 5)]++;
    }
    final total = _bpmHistory.isEmpty ? 1 : _bpmHistory.length;
    final zoneDist = counts.map((c) => (c / total * 100).round()).toList();
    var dominantZone = 1;
    var best = -1;
    for (var z = 1; z <= 5; z++) {
      if (counts[z] > best) {
        best = counts[z];
        dominantZone = z;
      }
    }
    final end = DateTime.now();
    try {
      await WorkoutRepository.save(
        userId: uid,
        type: widget.workoutType?.name ?? 'free',
        startTime: end.subtract(_stopwatch.elapsed),
        endTime: end,
        avgHr: avg,
        maxHr: _maxBpm,
        calories: _kcal.round(),
        trimp: _trimp.round(),
        zoneDist: zoneDist,
        dominantZone: dominantZone,
        sessionId: widget.session?.id,
      );
    } catch (_) {
      // Non-blocking; ignore transient write failures.
    }
  }

  @override
  Widget build(BuildContext context) {
    final hrMax = widget.profile.hrMax;
    final zone = HrZones.fromBpm(_bpm, hrMax);
    final zoneColor = AppColors.zoneColor(zone == 0 ? 1 : zone);
    // Shrink the BPM ring + spacing on short viewports (iPhone SE-class
    // phones at ~667px tall) so the bottom controls + leaderboard don't
    // overflow off-screen.
    final shortScreen = MediaQuery.of(context).size.height < 720;
    final bpmSize = shortScreen ? 220.0 : 280.0;

    return MobileFrame(
      child: Scaffold(
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

            SizedBox(height: shortScreen ? AppSpacing.sm : AppSpacing.lg),
            const Spacer(),

            // BIG BPM — shrinks on short viewports so the bottom controls fit.
            BpmDisplay(bpm: _bpm, hrMax: hrMax, size: bpmSize),

            SizedBox(height: shortScreen ? AppSpacing.sm : AppSpacing.lg),

            // Zone bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: ZoneBar(activeZone: zone == 0 ? 1 : zone),
            ),

            SizedBox(height: shortScreen ? AppSpacing.md : AppSpacing.xl),

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

            SizedBox(height: shortScreen ? AppSpacing.sm : 0),
            const Spacer(),

            // "View whole studio" button — only in group sessions.
            // Uses same horizontal padding as the controls below so widths match.
            if (widget.inGroupSession) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _ViewStudioButton(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TvHostScreen(),
                    ),
                  ),
                ),
              ),
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

/// "View whole studio" CTA shown to athletes in a group session.
/// Opens the TV-style grid so they can see everyone training together.
class _ViewStudioButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ViewStudioButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.darkBgSecondary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.brandRed.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandRed.withValues(alpha: 0.12),
                blurRadius: 16,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.brandRed.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.grid_view_rounded,
                  color: AppColors.brandRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'View whole studio',
                      style: AppTheme.bodyLarge(weight: FontWeight.w600)
                          .copyWith(fontSize: 15),
                    ),
                    Text(
                      'See everyone training together',
                      style: AppTheme.caption(),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.brandRed,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}