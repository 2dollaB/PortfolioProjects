import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/feature_flags.dart';
import '../config/hr_zones.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../models/cloud_session.dart';
import '../models/hr_data.dart';
import '../models/user_profile.dart';
import '../models/workout_type.dart';
import '../services/auth_service.dart';
import '../services/ble_hr_service.dart';
import '../services/clock_sync.dart';
import '../services/foreground_service.dart';
import '../services/session_repository.dart';
import '../services/workout_recovery_service.dart';
import '../services/workout_repository.dart';
import '../widgets/beat_button.dart';
import '../widgets/bpm_display.dart';
import '../widgets/floating_pills.dart';
import '../widgets/mobile_frame.dart';
import '../widgets/session_status_banner.dart';
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

  /// Optional interval timer for a solo workout (set from the solo setup).
  /// [workSec] == 0 means no interval timer — a plain open workout.
  final int workSec;
  final int restSec;
  final int rounds;

  const WorkoutScreen({
    super.key,
    required this.profile,
    this.inGroupSession = false,
    this.session,
    this.workSec = 0,
    this.restSec = 0,
    this.rounds = 1,
  });

  bool get hasIntervals => workSec > 0;

  /// Saved with the workout so history can distinguish group vs solo.
  String get _workoutTypeValue => session != null ? 'group' : 'solo';

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen>
    with WidgetsBindingObserver {
  Timer? _tick;
  final _stopwatch = Stopwatch();
  int _bpm = 78;
  int _maxBpm = 78;
  final List<int> _bpmHistory = [];
  bool _paused = false;
  final _rng = math.Random();
  double _kcal = 0;
  double _beatPoints = 0;

  // Zone Match (target-zone coaching) — seconds the workout ran while a target
  // was set, and the subset of those spent in the target zone.
  int _targetZone = 0;
  double _targetActiveSec = 0;
  double _matchSec = 0;

  /// % of active-with-target time spent in the target zone, or -1 when no
  /// target was ever set during the workout.
  int get _zoneMatchPct =>
      _targetActiveSec > 0 ? (_matchSec / _targetActiveSec * 100).round() : -1;

  // Real strap: locked in at workout start. When connected, _step consumes
  // the latest BLE sample instead of the simulated curve.
  late final bool _useBle;
  HrData? _lastBle;
  bool _bleLive = false;
  StreamSubscription<HrData>? _bleSub;

  /// Production group session — streamed so the athlete reacts to the trainer's
  /// pause / resume / end / kick. Pause is trainer-controlled in group mode.
  StreamSubscription<CloudSession?>? _sessionSub;
  bool _finishing = false; // guards against double save / navigation

  // 3-2-1 countdown before the elapsed-time clock actually starts. For a
  // group session this targets the session's shared `runningSince` instant
  // (set by SessionRepository.beginWorkout) so every athlete — and the
  // trainer — counts down to the exact same moment. Solo just counts down
  // locally from the moment the screen opens.
  late final DateTime _countdownTarget =
      widget.session?.runningSince ??
      DateTime.now().add(CloudSession.countdownDuration);
  int _countdown = 0;
  Timer? _countdownTimer;
  bool _showGo = false;
  bool get _countingDown => _countdown > 0 || _showGo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _useBle = !kIsWeb && BleHrService.instance.isConnected;
    if (_useBle) {
      _bleSub = BleHrService.instance.hrDataStream.listen((d) => _lastBle = d);
    }
    // Keeps HR tracking alive when the phone screen locks mid-workout.
    if (!kIsWeb && !FeatureFlags.prototypeMode) {
      unawaited(startForegroundService());
    }
    final gs = widget.session;
    if (gs != null && AuthService.currentUid != null) {
      _sessionSub = SessionRepository.watch(gs.id).listen(_onSessionUpdate);
      // Best-effort — corrects _countdownTarget's comparisons against this
      // device's own clock drift. Usually already synced from the lobby.
      unawaited(ClockSync.sync());
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // HR sampling + publishing starts right away — during the countdown too
    // — so the trainer's board (and this athlete's own BPM ring) show real
    // ticking numbers before the workout is officially "live". Only the
    // elapsed-time clock waits for _beginTracking().
    _tick = Timer.periodic(const Duration(milliseconds: 800), (_) => _step());
    _armCountdown();
  }

  void _recomputeCountdown() {
    final remaining = _countdownTarget.difference(ClockSync.now());
    _countdown = remaining.isNegative
        ? 0
        : (remaining.inMilliseconds / 1000).ceil();
  }

  void _armCountdown() {
    _recomputeCountdown();
    if (_countdown <= 0) {
      _flashGoThenBegin();
      return;
    }
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      _recomputeCountdown();
      if (_countdown <= 0) {
        _countdownTimer?.cancel();
        _flashGoThenBegin();
      } else {
        setState(() {});
      }
    });
  }

  /// Flashes "GO" briefly once the countdown hits zero, then starts the clock.
  void _flashGoThenBegin() {
    setState(() => _showGo = true);
    Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _showGo = false);
      _beginTracking();
    });
  }

  /// Starts the elapsed-time clock once the 3-2-1 countdown finishes.
  void _beginTracking() {
    _stopwatch.start();
  }

  /// Trainer-driven lifecycle for production group sessions.
  void _onSessionUpdate(CloudSession? s) {
    if (!mounted || _finishing) return;
    final uid = AuthService.currentUid;
    if (s == null) {
      _goToSummary(); // session doc gone — treat as ended
      return;
    }
    if (uid != null && s.isKicked(uid)) {
      _handleKicked();
      return;
    }
    if (s.status == 'ended') {
      _goToSummary();
      return;
    }
    // Mirror the trainer's pause/resume onto the local clock + tracking, and
    // track the trainer's current target zone for Zone Match %.
    setState(() {
      _targetZone = s.targetZone;
      if (s.isPaused && !_paused) {
        _paused = true;
        _stopwatch.stop();
      } else if (s.isRunning && _paused) {
        _paused = false;
        _stopwatch.start();
      }
    });
  }

  Future<void> _handleKicked() async {
    if (_finishing) return;
    _finishing = true;
    final session = widget.session;
    final uid = AuthService.currentUid;
    if (session != null && uid != null) {
      unawaited(
        SessionRepository.removeHr(
          sessionId: session.id,
          uid: uid,
        ).catchError((_) {}),
      );
    }
    // Kicked workouts aren't saved, so drop the crash-recovery snapshot too.
    unawaited(WorkoutRecoveryService.clear());
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(Strings.removedFromSession)));
  }

  void _step() {
    if (_paused || !mounted) return;
    setState(() {
      final int next;
      if (_useBle) {
        // Real sensor: hold the last reading through brief dropouts rather
        // than blending in fake data.
        final sample = _lastBle;
        _bleLive =
            sample != null &&
            DateTime.now().difference(sample.timestamp) <
                const Duration(seconds: 8);
        next = sample?.bpm ?? _bpm;
      } else {
        // Target curve: ramps up during the first minute, oscillates 130-170 after.
        final elapsedSec = _stopwatch.elapsed.inSeconds.toDouble();
        final base = elapsedSec < 60
            ? 78 + (elapsedSec / 60.0) * 70
            : 145 + math.sin(elapsedSec / 18) * 22;
        final noise = (_rng.nextDouble() - 0.5) * 6;
        next = (base + noise).round().clamp(60, 200);
      }
      _bpm = next;
      _maxBpm = math.max(_maxBpm, _bpm);
      _bpmHistory.add(_bpm);
      if (_bpmHistory.length > 120) _bpmHistory.removeAt(0);

      final hrMax = widget.profile.hrMax;
      // Calories — MET-per-type model, accumulated per ~0.8s tick. No workout
      // type picker feeds the live flow yet, so MET defaults to `free` (7.0).
      // Samples below 0.35×HRmax are gated out (rest doesn't count).
      if (_bpm >= 0.35 * hrMax) {
        _kcal += WorkoutType.free.met *
            (_bpm / hrMax * 0.95) *
            widget.profile.weightKg *
            (0.8 / 60) *
            (3.5 / 200);
      }
      // BeatPoints — points/min by current zone (z5 capped at z4, no bonus),
      // accumulated per ~0.8s tick. Paused ticks return early above, so a
      // paused clock earns nothing; signal gaps hold _bpm but stay in-band.
      final bpZone = HrZones.fromBpm(_bpm, hrMax);
      final bpPerMin = bpZone == 0 ? 0 : math.min(bpZone, 4);
      _beatPoints += bpPerMin * (0.8 / 60);
      // Zone Match — only while the clock is actually running and a target is
      // set. Time-weighted against the target that was active at the moment.
      if (_stopwatch.isRunning && _targetZone >= 1 && _targetZone <= 5) {
        _targetActiveSec += 0.8;
        if (bpZone == _targetZone) _matchSec += 0.8;
      }
    });
    _publishHr();
    _maybeSnapshot();
    // Solo interval timer finished all rounds → wrap up to the summary.
    final iv = _intervalState();
    if (iv != null && iv.done && !_finishing) {
      _goToSummary();
    }
  }

  /// Interval phase derived from elapsed workout time (deterministic, so it
  /// stays accurate regardless of tick jitter). Null when no interval timer.
  ({SessionPhase phase, int remainingSec, int round, bool done})?
  _intervalState() {
    if (!widget.hasIntervals) return null;
    var t = _stopwatch.elapsed.inSeconds;
    final w = widget.workSec, r = widget.restSec, rounds = widget.rounds;
    for (var round = 1; round <= rounds; round++) {
      if (t < w) {
        return (
          phase: SessionPhase.work,
          remainingSec: w - t,
          round: round,
          done: false,
        );
      }
      t -= w;
      if (round < rounds && r > 0) {
        if (t < r) {
          return (
            phase: SessionPhase.rest,
            remainingSec: r - t,
            round: round,
            done: false,
          );
        }
        t -= r;
      }
    }
    return (
      phase: SessionPhase.idle,
      remainingSec: 0,
      round: rounds,
      done: true,
    );
  }

  int get _avgBpm => _bpmHistory.isEmpty
      ? _bpm
      : _bpmHistory.reduce((a, b) => a + b) ~/ _bpmHistory.length;

  DateTime? _lastHrPush;
  DateTime? _lastSnapshot;

  /// ~5s crash-safety snapshot so a killed process doesn't lose the workout;
  /// WorkoutRecoveryService saves the leftover on the next launch.
  void _maybeSnapshot() {
    final now = DateTime.now();
    if (_lastSnapshot != null &&
        now.difference(_lastSnapshot!) < const Duration(seconds: 5)) {
      return;
    }
    _writeSnapshot();
  }

  /// Persists the current totals immediately (no throttle). Called on the ~5s
  /// tick and, crucially, the instant the app is backgrounded.
  void _writeSnapshot() {
    final uid = AuthService.currentUid;
    if (uid == null) return;
    final now = DateTime.now();
    _lastSnapshot = now;
    final stats = _zoneStats(widget.profile.hrMax);
    unawaited(
      WorkoutRecoveryService.snapshot({
        'userId': uid,
        'type': widget._workoutTypeValue,
        'startMs': now.subtract(_stopwatch.elapsed).millisecondsSinceEpoch,
        'lastMs': now.millisecondsSinceEpoch,
        'avgHr': _avgBpm,
        'maxHr': _maxBpm,
        'calories': _kcal.round(),
        'beatPoints': _beatPoints.round(),
        'zoneMatchPct': _zoneMatchPct,
        'zoneDist': stats.zoneDist,
        'dominantZone': stats.dominantZone,
        'sessionId': widget.session?.id,
      }),
    );
  }

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
      name: widget.profile.name,
      bpm: _bpm,
      avgBpm: _avgBpm,
      zone: HrZones.fromBpm(_bpm, hrMax).clamp(0, 5),
      hrMax: hrMax,
      beatPoints: _beatPoints.round(),
      profileConfirmed: widget.profile.profileConfirmed,
    ).catchError((_) {});
  }

  /// A backgrounded workout is the moment the OS is most likely to kill the
  /// process (aggressive OEMs — ColorOS/MIUI — reap swiped-away apps despite
  /// the foreground service). Snapshot right now, bypassing the 5s throttle,
  /// so WorkoutRecoveryService has the freshest totals to restore on relaunch.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _writeSnapshot();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _countdownTimer?.cancel();
    _bleSub?.cancel();
    _sessionSub?.cancel();
    if (!kIsWeb && !FeatureFlags.prototypeMode) {
      unawaited(stopForegroundService());
    }
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
    // Already ending elsewhere (e.g. the trainer ended the session while
    // this dialog was about to open) — don't show a confirm that can never
    // do anything, and don't re-enter _goToSummary.
    if (_finishing) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        title: Text(Strings.endWorkoutTitle),
        content: Text(
          Strings.endWorkoutBody,
          style: AppTheme.bodyLarge(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(Strings.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.brandRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(Strings.endLabel),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _goToSummary();
    }
  }

  /// Finalize the workout: drop off the live board, persist the summary, and
  /// show the results. Shared by the athlete's Leave/End and the trainer's End.
  /// Guarded so trainer-end + manual-leave can't both fire it.
  Future<void> _goToSummary() async {
    if (_finishing) return;
    _finishing = true;
    // Freeze the engine before anything else: the summary route's builder
    // closes over this State and re-runs on theme/locale rebuilds, so a
    // still-ticking clock made the summary drift away from the saved
    // workout (E2E-7).
    _tick?.cancel();
    _sessionSub?.cancel();
    _stopwatch.stop();
    final session = widget.session;
    final uid = AuthService.currentUid;
    if (session != null && uid != null) {
      // Drop off the live board; fails harmlessly if the session ended.
      unawaited(
        SessionRepository.removeHr(
          sessionId: session.id,
          uid: uid,
        ).catchError((_) {}),
      );
    }
    unawaited(_persistWorkout());
    unawaited(WorkoutRecoveryService.clear());
    if (!mounted) return;
    // Capture once — the builder must not read live fields.
    final durationMin = _stopwatch.elapsed.inMinutes;
    final avgBpm = _avgBpm;
    final maxBpm = _maxBpm;
    final calories = _kcal.round();
    final beatPoints = _beatPoints.round();
    final zoneDist = _zoneStats(widget.profile.hrMax).zoneDist;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => WorkoutSummaryScreen(
          durationMin: durationMin,
          avgBpm: avgBpm,
          maxBpm: maxBpm,
          calories: calories,
          beatPoints: beatPoints,
          profile: widget.profile,
          isGroup: widget.session != null,
          zoneDist: zoneDist,
        ),
      ),
    );
  }

  /// Persist this session's summary to Firestore when signed in (production).
  /// Fire-and-forget: navigation isn't blocked and Firestore's offline queue
  /// handles transient failures.
  Future<void> _persistWorkout() async {
    final uid = AuthService.currentUid;
    if (uid == null) return; // prototype / not signed in
    final stats = _zoneStats(widget.profile.hrMax);
    final end = DateTime.now();
    try {
      await WorkoutRepository.save(
        userId: uid,
        type: widget._workoutTypeValue,
        startTime: end.subtract(_stopwatch.elapsed),
        endTime: end,
        avgHr: _avgBpm,
        maxHr: _maxBpm,
        calories: _kcal.round(),
        beatPoints: _beatPoints.round(),
        zoneMatchPct: _zoneMatchPct,
        zoneDist: stats.zoneDist,
        dominantZone: stats.dominantZone,
        sessionId: widget.session?.id,
      );
    } catch (_) {
      // Non-blocking; ignore transient write failures.
    }
  }

  /// Zone distribution (% of samples per zone 0-5) + dominant training zone.
  ({List<int> zoneDist, int dominantZone}) _zoneStats(int hrMax) {
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
    return (zoneDist: zoneDist, dominantZone: dominantZone);
  }

  /// Top-right sensor chip: real device name + battery when a strap is
  /// connected, an honest "Simulated" in production without one, and the
  /// polished mock chip for the prototype demo.
  Widget _sensorChip() {
    final IconData icon;
    final Color color;
    final String label;
    if (_useBle) {
      final ble = BleHrService.instance;
      final name = ble.connectedDeviceName ?? 'Sensor';
      final batt = ble.batteryLevel;
      label = batt >= 0 ? '$name · $batt%' : name;
      color = _bleLive ? AppColors.success : AppColors.textTertiary;
      icon = _bleLive
          ? Icons.bluetooth_connected_rounded
          : Icons.bluetooth_disabled_rounded;
    } else if (AuthService.currentUid != null) {
      label = Strings.simulated;
      color = AppColors.textSecondary;
      icon = Icons.bluetooth_disabled_rounded;
    } else {
      label = 'H10 · ${(85 + _rng.nextInt(15))}%';
      color = AppColors.success;
      icon = Icons.bluetooth_connected_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.micro,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTheme.caption(
              color: color,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
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
        backgroundColor: AppColors.bgPrimary,
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  // Live indicator + close
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      0,
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
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              border: Border.all(
                                color: AppColors.brandRed.withValues(
                                  alpha: 0.3,
                                ),
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
                                  Strings.liveStudioSession,
                                  style: AppTheme.micro(
                                    color: AppColors.brandRed,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Spacer(),
                        _sensorChip(),
                      ],
                    ),
                  ),

                  if (_paused)
                    Container(
                      margin: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xs,
                        AppSpacing.md,
                        0,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.pause_rounded,
                            size: 16,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.inGroupSession
                                ? Strings.pausedByTrainer
                                : Strings.paused,
                            style: AppTheme.caption(
                              color: AppColors.warning,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),

                  // Solo interval timer — WORK/REST + remaining + round.
                  if (widget.hasIntervals && !_countingDown) ...[
                    Builder(
                      builder: (context) {
                        final iv = _intervalState();
                        if (iv == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            AppSpacing.sm,
                            AppSpacing.md,
                            0,
                          ),
                          child: Center(
                            child: PhasePill(
                              phase: iv.done ? SessionPhase.idle : iv.phase,
                              remaining: Duration(seconds: iv.remainingSec),
                              roundLabel: iv.done
                                  ? Strings.complete
                                  : Strings.roundOf(iv.round, widget.rounds),
                            ),
                          ),
                        );
                      },
                    ),
                  ],

                  SizedBox(height: shortScreen ? AppSpacing.sm : AppSpacing.lg),
                  const Spacer(),

                  // BIG BPM — shrinks on short viewports so the bottom controls fit.
                  BpmDisplay(bpm: _bpm, hrMax: hrMax, size: bpmSize),

                  SizedBox(height: shortScreen ? AppSpacing.sm : AppSpacing.lg),

                  // Zone bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: ZoneBar(activeZone: zone == 0 ? 1 : zone),
                  ),

                  SizedBox(height: shortScreen ? AppSpacing.md : AppSpacing.xl),

                  // Stats row
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _LiveStat(
                            label: Strings.duration,
                            value: _formatDuration(_stopwatch.elapsed),
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: AppColors.border,
                        ),
                        Expanded(
                          child: _LiveStat(
                            label: Strings.calories,
                            value: _kcal.round().toString(),
                            unit: 'kcal',
                            color: zoneColor,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: AppColors.border,
                        ),
                        Expanded(
                          child: _LiveStat(
                            label: Strings.beatPoints,
                            value: _beatPoints.toStringAsFixed(0),
                            color: AppColors.textPrimary,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      child: _ViewStudioButton(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TvHostScreen(
                              studioId: widget.session == null
                                  ? null
                                  : widget.profile.studioId,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],

                  // Controls
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xs,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    // In a group session, Pause/Resume is the trainer's call — the
                    // athlete just gets Leave. Solo workouts keep their own Pause.
                    child: widget.inGroupSession
                        ? BeatPrimaryButton(
                            label: Strings.leave,
                            icon: Icons.stop_rounded,
                            onPressed: _endWorkout,
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: BeatSecondaryButton(
                                  label: _paused
                                      ? Strings.resume
                                      : Strings.pause,
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
                                  label: Strings.endLabel,
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
            if (_countingDown)
              _CountdownOverlay(value: _countdown, showGo: _showGo),
          ],
        ),
      ),
    );
  }
}

/// Full-screen 3-2-1 countdown shown before the clock + elapsed time start.
/// HR sampling is already running underneath, so the trainer's board (and
/// this athlete's own numbers, once revealed) tick during this screen too.
class _CountdownOverlay extends StatelessWidget {
  final int value;
  final bool showGo;
  const _CountdownOverlay({required this.value, required this.showGo});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: AppColors.bgPrimary,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Strings.getReady,
              style: AppTheme.h2().copyWith(letterSpacing: 2),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              showGo ? '' : Strings.startingIn,
              style: AppTheme.caption(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Text(
                showGo ? Strings.go : '$value',
                key: ValueKey(showGo ? -1 : value),
                style: AppTheme.statNumber(
                  fontSize: 120,
                  color: AppColors.brandRed,
                ),
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
            color: AppColors.bgSecondary,
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
                      Strings.viewWholeStudio,
                      style: AppTheme.bodyLarge(
                        weight: FontWeight.w600,
                      ).copyWith(fontSize: 15),
                    ),
                    Text(Strings.seeEveryone, style: AppTheme.caption()),
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
