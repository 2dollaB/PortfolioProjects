import 'dart:async';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../config/hr_zones.dart';
import '../config/theme.dart';
import '../models/user_profile.dart';
import '../models/workout.dart';
import '../services/audio_cue_service.dart';
import '../models/workout_type.dart';
import '../services/ble_hr_service.dart';
import '../services/foreground_service.dart';
import '../services/session_client.dart';
import '../services/storage_service.dart';
import '../services/tv_server.dart';
import 'workout_summary_screen.dart';

class WorkoutScreen extends StatefulWidget {
  final UserProfile profile;
  final BleHrService bleService;
  final TvServer? tvServer;
  final SessionClient? sessionClient;
  final WorkoutType workoutType;

  const WorkoutScreen({
    super.key,
    required this.profile,
    required this.bleService,
    this.tvServer,
    this.sessionClient,
    this.workoutType = WorkoutType.free,
  });

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen>
    with SingleTickerProviderStateMixin {
  bool _isPaused = false;
  bool _isCountingDown = true;
  int _countdownValue = 3;
  Timer? _countdownTimer;
  late DateTime _startTime;
  Duration _elapsed = Duration.zero;
  Duration _pausedDuration = Duration.zero;
  DateTime? _pauseStart;
  Timer? _timer;

  final List<HrDataPoint> _dataPoints = [];
  final List<FlSpot> _chartSpots = [];
  final List<Duration> _lapMarkers = []; // Elapsed time at each lap
  int _currentBpm = 0;
  int _currentZone = 0;
  int _prevZone = 0; // For zone transition alerts
  int _maxBpm = 0;
  int _totalBpm = 0;
  int _bpmCount = 0;

  // Zone badge pulse animation
  bool _zonePulse = false;

  // 7.1 — Solo interval timer
  bool _soloIntervalActive = false;
  bool _isWorkPhase = true;
  int _intervalRemaining = 0;
  int _soloWorkSeconds = 40;
  int _soloRestSeconds = 20;
  Timer? _intervalTimer;

  // 7.7 — Auto-lap (UX-7: now settable)
  int _autoLapMinutes = 0; // 0 = off
  DateTime? _lastAutoLap;

  // 7.8 — Hydration reminder
  DateTime? _lastHydrationReminder;
  bool _showHydrationBanner = false;

  // UX-1 — BLE disconnect detection
  bool _bleDisconnected = false;
  StreamSubscription? _connectionSub;

  // UX-3 — Battery & RSSI
  int _batteryLevel = -1;
  int _rssi = 0;
  StreamSubscription? _batterySub;
  StreamSubscription? _rssiSub;

  // UX-4 — HR Recovery countdown
  bool _showRecoveryOverlay = false;
  int _recoverySecondsLeft = 60;

  // UX-9 — Zone transition banner
  String? _zoneBannerText;
  Color _zoneBannerColor = Colors.grey;

  // 2.10 — Zone target alert (0 = off)
  int _targetZone = 0;
  bool _belowTargetZone = false;

  // 2.3 — Goal setting (0 = off)
  int _goalMinutes = 0;
  bool _goalReached = false;

  StreamSubscription? _hrSub;

  late AnimationController _gaugeAnimController;
  double _animatedProgress = 0.0;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _startTime = DateTime.now();
    _startForegroundService();
    _gaugeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // 2.6 — Init audio cues
    AudioCueService.init();

    // UX-1 — Monitor BLE connection
    _connectionSub = widget.bleService.connectionState.listen((state) {
      if (!mounted) return;
      final disconnected = state == BleConnectionState.disconnected || state == BleConnectionState.error;
      if (disconnected && !_bleDisconnected && _currentBpm > 0) {
        HapticFeedback.heavyImpact();
      }
      setState(() => _bleDisconnected = disconnected);
    });

    // UX-3 — Battery & RSSI
    _batterySub = widget.bleService.batteryStream.listen((level) {
      if (mounted) setState(() => _batteryLevel = level);
    });
    _rssiSub = widget.bleService.rssiStream.listen((r) {
      if (mounted) setState(() => _rssi = r);
    });
    _batteryLevel = widget.bleService.batteryLevel;
    _rssi = widget.bleService.rssi;

    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdownValue > 1) {
        setState(() => _countdownValue--);
        HapticFeedback.lightImpact();
      } else {
        t.cancel();
        HapticFeedback.heavyImpact();
        setState(() => _isCountingDown = false);
        _startTime = DateTime.now();
        _startTimer();
        _listenToHr();
        startForegroundService();
      }
    });
  }

  void _startForegroundService() {
    // Will be started after countdown
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused) {
        setState(() => _elapsed = DateTime.now().difference(_startTime) - _pausedDuration);

        // 2.3 — Goal completion check
        if (_goalMinutes > 0 && !_goalReached && _elapsed.inMinutes >= _goalMinutes) {
          _goalReached = true;
          HapticFeedback.heavyImpact();
          AudioCueService.announceMilestone('Goal reached! $_goalMinutes minutes complete.');
          setState(() {
            _zoneBannerText = '🎉 GOAL REACHED — $_goalMinutes min!';
            _zoneBannerColor = AppTheme.success;
          });
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) setState(() => _zoneBannerText = null);
          });
        }

        // 7.7 — Auto-lap check
        if (_autoLapMinutes > 0) {
          final now = DateTime.now();
          if (_lastAutoLap == null || now.difference(_lastAutoLap!).inMinutes >= _autoLapMinutes) {
            if (_lastAutoLap != null) {
              _lapMarkers.add(_elapsed);
              HapticFeedback.selectionClick();
            }
            _lastAutoLap = now;
          }
        }

        // 7.8 — Hydration reminder (every 20 min)
        if (_elapsed.inMinutes >= 20) {
          final now = DateTime.now();
          if (_lastHydrationReminder == null ||
              now.difference(_lastHydrationReminder!).inMinutes >= 20) {
            _lastHydrationReminder = now;
            HapticFeedback.heavyImpact();
            setState(() => _showHydrationBanner = true);
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted) setState(() => _showHydrationBanner = false);
            });
          }
        }
      }
    });
  }

  void _listenToHr() {
    _hrSub = widget.bleService.hrDataStream.listen((data) {
      if (_isPaused || _isCountingDown) return;

      final zone = HrZones.fromBpm(data.bpm, widget.profile.hrMax);
      final now = DateTime.now();
      widget.profile.updateDynamicHrMax(data.bpm);

      final newProgress = _bpmToProgress(data.bpm);

      // Zone transition alert
      if (zone != _prevZone && _prevZone != 0) {
        _triggerZoneAlert(zone);
      }

      setState(() {
        _currentBpm = data.bpm;
        _currentZone = zone;
        _prevZone = zone;
        if (data.bpm > _maxBpm) _maxBpm = data.bpm;
        _totalBpm += data.bpm;
        _bpmCount++;

        // Chart data — limit to last 200 points for smooth UI
        _chartSpots.add(FlSpot(
          _elapsed.inSeconds.toDouble(), data.bpm.toDouble()));
        if (_chartSpots.length > 200) {
          _chartSpots.removeAt(0);
        }

        // Data points
        _dataPoints.add(HrDataPoint(
          bpm: data.bpm,
          zone: zone,
          timestamp: now,
          rrIntervals: data.rrIntervals,
        ));
      });

      // Animate gauge
      _gaugeAnimController.reset();
      final tween = Tween<double>(begin: _animatedProgress, end: newProgress);
      final anim = tween.animate(CurvedAnimation(
        parent: _gaugeAnimController, curve: Curves.easeOut,
      ));
      anim.addListener(() {
        setState(() => _animatedProgress = anim.value);
      });
      _gaugeAnimController.forward();

      // Send to group session
      if (widget.tvServer != null && widget.tvServer!.isRunning) {
        widget.tvServer!.updateUserHr(
          userId: widget.profile.id,
          name: widget.profile.name,
          bpm: data.bpm, zone: zone, hrMax: widget.profile.hrMax,
        );
      }
      if (widget.sessionClient != null && widget.sessionClient!.isConnected) {
        widget.sessionClient!.sendHrUpdate(
          userId: widget.profile.id,
          name: widget.profile.name,
          bpm: data.bpm, zone: zone, hrMax: widget.profile.hrMax,
        );
      }
      updateForegroundNotification('${data.bpm} BPM — Zone $zone');
    });
  }

  void _triggerZoneAlert(int newZone) {
    // Haptic intensity scales with zone
    if (newZone >= 4) {
      HapticFeedback.heavyImpact();
    } else if (newZone == 3) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    // Visual pulse
    setState(() => _zonePulse = true);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _zonePulse = false);
    });

    // 2.6 — Audio cue for zone change
    final zoneName = HrZones.names[newZone] ?? 'Zone $newZone';
    AudioCueService.announceZone(newZone, zoneName);

    // UX-9 — Zone transition banner
    final name = HrZones.names[newZone] ?? 'Zone $newZone';
    final arrow = newZone > _prevZone ? '↑' : '↓';
    final color = HrZones.colors[newZone] ?? Colors.grey;
    setState(() {
      _zoneBannerText = '$arrow Zone $newZone — $name';
      _zoneBannerColor = color;

      // 2.10 — Below-target zone alert
      if (_targetZone > 0 && newZone < _targetZone) {
        _belowTargetZone = true;
        HapticFeedback.heavyImpact();
        AudioCueService.announceBelowTarget(_targetZone);
        _zoneBannerText = '⚠️ BELOW TARGET — Push to Zone $_targetZone!';
        _zoneBannerColor = const Color(0xFFEF4444);
      } else {
        _belowTargetZone = false;
      }
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _zoneBannerText = null);
    });
  }

  void _recordLap() {
    HapticFeedback.selectionClick();
    setState(() => _lapMarkers.add(_elapsed));
  }

  // ── 7.1 Solo Interval ──
  void _startSoloInterval() {
    HapticFeedback.mediumImpact();
    setState(() {
      _soloIntervalActive = true;
      _isWorkPhase = true;
      _intervalRemaining = _soloWorkSeconds;
    });
    _intervalTimer?.cancel();
    _intervalTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isPaused) return;
      setState(() {
        _intervalRemaining--;
        if (_intervalRemaining <= 0) {
          HapticFeedback.heavyImpact();
          _isWorkPhase = !_isWorkPhase;
          _intervalRemaining = _isWorkPhase ? _soloWorkSeconds : _soloRestSeconds;
          if (_isWorkPhase) _lapMarkers.add(_elapsed); // auto-lap on new round
        }
      });
    });
  }

  void _stopSoloInterval() {
    _intervalTimer?.cancel();
    setState(() => _soloIntervalActive = false);
  }

  double _bpmToProgress(int bpm) {
    const minBpm = 50.0;
    final maxBpm = widget.profile.hrMax.toDouble();
    return ((bpm - minBpm) / (maxBpm - minBpm)).clamp(0.0, 1.0);
  }

  void _togglePause() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _pauseStart = DateTime.now();
      } else if (_pauseStart != null) {
        _pausedDuration += DateTime.now().difference(_pauseStart!);
        _pauseStart = null;
      }
    });
  }

  Future<void> _stopWorkout() async {
    HapticFeedback.heavyImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('End Workout?', style: AppTheme.heading(fontSize: 20)),
        content: Text('Your workout data will be saved.',
            style: AppTheme.body(fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTheme.body(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('End Workout', style: AppTheme.body(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        _timer?.cancel();
        _intervalTimer?.cancel();
        stopForegroundService();

        // Account for any ongoing pause
        if (_isPaused && _pauseStart != null) {
          _pausedDuration += DateTime.now().difference(_pauseStart!);
        }
        final finalElapsed = DateTime.now().difference(_startTime) - _pausedDuration;
        widget.tvServer?.removeUser(widget.profile.id);
        widget.sessionClient?.sendRemove(widget.profile.id);

        // ── HR Recovery measurement (only with sufficient data + BLE) ──
        int recoveryBpm = 0;
        final endBpm = _currentBpm;

        if (endBpm > 0 && _dataPoints.length >= 10 && widget.bleService.isConnected && mounted) {
          // UX-4 — Show recovery countdown overlay
          setState(() {
            _isPaused = true;
            _showRecoveryOverlay = true;
            _recoverySecondsLeft = 60;
          });
          int lowestBpm = endBpm;
          StreamSubscription? recoverySub;
          recoverySub = widget.bleService.hrDataStream.listen((data) {
            if (data.bpm < lowestBpm && data.bpm > 0) lowestBpm = data.bpm;
          });

          // Countdown with visible updates
          final completer = Completer<void>();
          Timer.periodic(const Duration(seconds: 1), (timer) {
            if (!mounted || !_showRecoveryOverlay || _recoverySecondsLeft <= 1) {
              timer.cancel();
              completer.complete();
              return;
            }
            setState(() => _recoverySecondsLeft--);
          });
          await completer.future;
          await recoverySub.cancel();
          recoveryBpm = (endBpm - lowestBpm).clamp(0, 200);
          if (mounted) setState(() => _showRecoveryOverlay = false);
        }

        final analytics = AnalyticsEngine.calculate(
          dataPoints: _dataPoints,
          profile: widget.profile,
          totalDuration: finalElapsed,
          hrRecoveryBpm: recoveryBpm,
        );
        final workout = Workout(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          startTime: _startTime,
          endTime: DateTime.now(),
          dataPoints: _dataPoints,
          analytics: analytics,
          workoutType: widget.workoutType,
          lapMarkers: List.unmodifiable(_lapMarkers),
        );
        await StorageService.saveWorkout(workout);
        await StorageService.saveProfile(widget.profile);

        if (!mounted) return;

        // UX-8 — Save confirmation toast
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Workout saved!', style: AppTheme.body(color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: AppTheme.success,
            duration: const Duration(milliseconds: 800),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (_, __, ___) => WorkoutSummaryScreen(workout: workout),
            transitionsBuilder: (_, anim, __, child) {
              return SlideTransition(
                position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                ),
                child: FadeTransition(opacity: anim, child: child),
              );
            },
          ),
        );
      } catch (e) {
        debugPrint('[BeatSync] End workout error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error ending workout: $e'), backgroundColor: AppTheme.danger),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    _intervalTimer?.cancel();
    _hrSub?.cancel();
    _connectionSub?.cancel();
    _batterySub?.cancel();
    _rssiSub?.cancel();
    _gaugeAnimController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final zoneColor = HrZones.colors[_currentZone] ?? Colors.grey;
    final zoneName = HrZones.names[_currentZone] ?? 'Rest';
    final avgHr = _bpmCount > 0 ? (_totalBpm / _bpmCount).round() : 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stopWorkout();
      },
      child: Stack(
        children: [
          Scaffold(
            body: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.3),
              radius: 1.0,
              colors: [
                zoneColor.withValues(alpha: 0.06),
                AppTheme.background,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 4),

                // ── Top bar ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _stopWorkout,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.chevron_left_rounded, size: 22, color: AppTheme.textSecondary),
                        ),
                      ),
                      const Spacer(),
                      Text('BEATSYNC ACTIVE',
                          style: AppTheme.mono(
                            fontSize: 12, letterSpacing: 2,
                            color: AppTheme.accent, fontWeight: FontWeight.w700,
                          )),
                      const Spacer(),
                      // UX-3 — Battery & RSSI
                      if (_batteryLevel >= 0) ...[
                        Icon(
                          _batteryLevel > 60 ? Icons.battery_full
                              : _batteryLevel > 20 ? Icons.battery_3_bar
                              : Icons.battery_alert,
                          size: 16,
                          color: _batteryLevel > 20 ? AppTheme.success : AppTheme.danger,
                        ),
                        const SizedBox(width: 2),
                        Text('$_batteryLevel%',
                            style: AppTheme.mono(fontSize: 10, color: AppTheme.textMuted)),
                        const SizedBox(width: 8),
                      ],
                      if (_rssi != 0)
                        Icon(
                          _rssi > -60 ? Icons.signal_cellular_alt
                              : _rssi > -80 ? Icons.signal_cellular_alt_2_bar
                              : Icons.signal_cellular_alt_1_bar,
                          size: 16,
                          color: _rssi > -60 ? AppTheme.success
                              : _rssi > -80 ? AppTheme.warning : AppTheme.danger,
                        )
                      else
                        Icon(Icons.favorite, color: AppTheme.accent, size: 20),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Circular HR Gauge ──
                SizedBox(
                  width: 240,
                  height: 240,
                  child: CustomPaint(
                    painter: _HrGaugePainter(
                      progress: _animatedProgress,
                      zoneColor: zoneColor,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('BPM',
                            style: AppTheme.body(
                              fontSize: 11, color: AppTheme.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: ScaleTransition(
                                scale: Tween(begin: 0.85, end: 1.0).animate(anim),
                                child: child,
                              ),
                            ),
                            child: Text(
                              _currentBpm > 0 ? '$_currentBpm' : '--',
                              key: ValueKey(_currentBpm),
                              style: AppTheme.bpmDisplay(
                                fontSize: 64, glowColor: zoneColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                            decoration: BoxDecoration(
                              color: zoneColor.withValues(alpha: _zonePulse ? 0.4 : 0.15),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _zonePulse ? [
                                BoxShadow(color: zoneColor.withValues(alpha: 0.5), blurRadius: 12),
                              ] : null,
                            ),
                            child: Text(
                              'ZONE $_currentZone · ${zoneName.toUpperCase()}',
                              style: AppTheme.mono(
                                fontSize: 10, fontWeight: FontWeight.w700,
                                color: zoneColor, letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2.10 & 2.3 — Target Zone + Goal Chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Zone target chip
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _targetZone = (_targetZone + 1) % 6);
                        if (_targetZone == 1) setState(() => _targetZone = 2);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _targetZone > 0
                              ? (HrZones.colors[_targetZone] ?? Colors.grey).withValues(alpha: 0.15)
                              : AppTheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _targetZone > 0
                                ? (HrZones.colors[_targetZone] ?? Colors.grey).withValues(alpha: 0.3)
                                : AppTheme.surfaceLight,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.gps_fixed, size: 11,
                              color: _targetZone > 0 ? HrZones.colors[_targetZone] : AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              _targetZone > 0 ? 'Zone $_targetZone' : 'Zone',
                              style: AppTheme.mono(fontSize: 9, fontWeight: FontWeight.w600,
                                color: _targetZone > 0
                                    ? HrZones.colors[_targetZone] ?? AppTheme.textSecondary
                                    : AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 2.3 — Goal chip
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        const goals = [0, 15, 30, 45, 60];
                        final idx = goals.indexOf(_goalMinutes);
                        setState(() {
                          _goalMinutes = goals[(idx + 1) % goals.length];
                          _goalReached = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _goalMinutes > 0
                              ? (_goalReached ? AppTheme.success : AppTheme.accent).withValues(alpha: 0.15)
                              : AppTheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _goalMinutes > 0
                                ? (_goalReached ? AppTheme.success : AppTheme.accent).withValues(alpha: 0.3)
                                : AppTheme.surfaceLight,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_goalReached ? Icons.check_circle : Icons.flag_rounded, size: 11,
                              color: _goalMinutes > 0
                                  ? (_goalReached ? AppTheme.success : AppTheme.accent)
                                  : AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              _goalMinutes > 0
                                  ? (_goalReached ? 'Done!' : '${_goalMinutes}m')
                                  : 'Goal',
                              style: AppTheme.mono(fontSize: 9, fontWeight: FontWeight.w600,
                                color: _goalMinutes > 0
                                    ? (_goalReached ? AppTheme.success : AppTheme.accent)
                                    : AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── Metric Cards Grid ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _buildMetricTile(
                        Icons.timer_outlined, 'DURATION',
                        _formatDuration(_elapsed), AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      _buildMetricTile(
                        Icons.local_fire_department, 'CALORIES',
                        '${_estimateCalories()}', const Color(0xFFF97316),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _buildMetricTile(
                        Icons.favorite_outline, 'AVG BPM',
                        '$avgHr', AppTheme.accent,
                      ),
                      const SizedBox(width: 8),
                      _buildMetricTile(
                        Icons.arrow_upward_rounded, 'MAX BPM',
                        '$_maxBpm', HrZones.colors[5]!,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // 2.1 — Live TRIMP Gauge
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Builder(builder: (_) {
                    // Simplified real-time TRIMP: duration(min) × intensity
                    final durationMin = _elapsed.inSeconds / 60.0;
                    final hrRatio = avgHr > 0 ? avgHr / widget.profile.hrMax : 0.0;
                    final trimp = (durationMin * hrRatio * 1.5).round();
                    final trimpColor = trimp < 50
                        ? AppTheme.success
                        : trimp < 100
                            ? AppTheme.warning
                            : AppTheme.danger;
                    final trimpLabel = trimp < 50
                        ? 'Light'
                        : trimp < 100
                            ? 'Moderate'
                            : trimp < 150
                                ? 'Hard'
                                : 'Extreme';
                    final progress = (trimp / 200).clamp(0.0, 1.0);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: AppTheme.glowCard(color: trimpColor, intensity: 0.1),
                      child: Row(
                        children: [
                          Icon(Icons.local_fire_department, size: 18, color: trimpColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('TRIMP',
                                        style: AppTheme.mono(fontSize: 9, color: AppTheme.textMuted,
                                            letterSpacing: 1, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 6),
                                    Text(trimpLabel,
                                        style: AppTheme.body(fontSize: 10, color: trimpColor,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 4,
                                    backgroundColor: trimpColor.withValues(alpha: 0.12),
                                    valueColor: AlwaysStoppedAnimation(trimpColor),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('$trimp',
                              style: AppTheme.heading(fontSize: 20, fontWeight: FontWeight.w700,
                                  color: trimpColor)),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 14),

                // ── Real-Time HR Chart ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('REAL-TIME HR',
                                style: AppTheme.mono(
                                  fontSize: 11, letterSpacing: 1.5,
                                  color: AppTheme.textMuted,
                                )),
                            const Spacer(),
                            if (_bpmCount > 1)
                              Text('+${(_currentBpm - avgHr).abs()} vs avg',
                                  style: AppTheme.mono(
                                    fontSize: 10,
                                    color: _currentBpm >= avgHr ? AppTheme.accent : AppTheme.success,
                                  )),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Expanded(child: _buildHrChart()),
                      ],
                    ),
                  ),
                ),

                // ── Zone Distribution Bar ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Column(
                    children: [
                      Text('ZONE DISTRIBUTION',
                          style: AppTheme.mono(
                            fontSize: 10, letterSpacing: 1.5,
                            color: AppTheme.textMuted,
                          )),
                      const SizedBox(height: 6),
                      _buildLiveZoneBar(),
                    ],
                  ),
                ),

                // ── 7.1 Solo Interval Panel (HIIT only, no group) ──
                if (widget.workoutType.hasIntervals && widget.tvServer == null && widget.sessionClient == null && !_isCountingDown)
                  _buildSoloIntervalPanel(),

                // ── Controls ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Row(
                    children: [
                      // PAUSE button
                      Expanded(
                        child: GestureDetector(
                          onTap: _isCountingDown ? null : _togglePause,
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.accent, AppTheme.accentDark],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                                  size: 24, color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isPaused ? 'RESUME' : 'PAUSE',
                                  style: AppTheme.mono(
                                    fontSize: 14, fontWeight: FontWeight.w700,
                                    color: Colors.white, letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // LAP button (only for HIIT or if laps exist)
                      if (widget.workoutType.hasLaps || _lapMarkers.isNotEmpty) ...[
                        GestureDetector(
                          onTap: _isCountingDown || _isPaused ? null : _recordLap,
                          child: Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.flag_rounded, size: 18, color: AppTheme.accent),
                                Text('LAP', style: AppTheme.mono(fontSize: 8, color: AppTheme.accent, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      // STOP button — UX-D: labeled with red tint
                      GestureDetector(
                        onTap: _isCountingDown ? null : _stopWorkout,
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.danger.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.stop_rounded, size: 22, color: AppTheme.danger.withValues(alpha: 0.8)),
                              const SizedBox(width: 4),
                              Text('END', style: AppTheme.mono(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: AppTheme.danger.withValues(alpha: 0.8), letterSpacing: 1,
                              )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      // ── Countdown Overlay ──
      if (_isCountingDown)
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.85),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.workoutType.displayName.toUpperCase(),
                  style: AppTheme.mono(
                    fontSize: 14, letterSpacing: 3,
                    color: AppTheme.accent, fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                TweenAnimationBuilder<double>(
                  key: ValueKey(_countdownValue),
                  tween: Tween(begin: 1.5, end: 1.0),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                  builder: (ctx, scale, _) => Transform.scale(
                    scale: scale,
                    child: Text(
                      '$_countdownValue',
                      style: AppTheme.heading(
                        fontSize: 120, fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text('GET READY',
                    style: AppTheme.mono(
                      fontSize: 16, letterSpacing: 4,
                      color: AppTheme.textMuted, fontWeight: FontWeight.w500,
                    )),
              ],
            ),
          ),
        ),
      // ── 7.8 Hydration Banner ──
      if (_showHydrationBanner)
        Positioned(
          top: 80,
          left: 20,
          right: 20,
          child: AnimatedOpacity(
            opacity: _showHydrationBanner ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Text('💧', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Time to hydrate! Take a sip.',
                        style: AppTheme.body(
                          fontSize: 14, color: Colors.white,
                          fontWeight: FontWeight.w600,
                        )),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _showHydrationBanner = false),
                    child: const Icon(Icons.close, size: 18, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
        // UX-1 — BLE Disconnect Banner
        if (_bleDisconnected && !_isCountingDown)
          Positioned(
            top: MediaQuery.of(context).padding.top + 50,
            left: 16, right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: AppTheme.danger.withValues(alpha: 0.3), blurRadius: 12)],
              ),
              child: Row(
                children: [
                  const Icon(Icons.bluetooth_disabled, size: 20, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('HR Monitor Disconnected',
                            style: AppTheme.body(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                        Text('Trying to reconnect...',
                            style: AppTheme.body(fontSize: 11, color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

        // UX-9 — Zone Transition Banner
        if (_zoneBannerText != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 50,
            left: 40, right: 40,
            child: AnimatedOpacity(
              opacity: _zoneBannerText != null ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _zoneBannerColor.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: _zoneBannerColor.withValues(alpha: 0.4), blurRadius: 12)],
                ),
                child: Text(
                  _zoneBannerText ?? '',
                  textAlign: TextAlign.center,
                  style: AppTheme.heading(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
          ),

        // UX-4 — HR Recovery Countdown
        if (_showRecoveryOverlay)
          Container(
            color: Colors.black87,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 120, height: 120,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: _recoverySecondsLeft / 60.0,
                          strokeWidth: 6,
                          backgroundColor: AppTheme.surfaceLight,
                          color: AppTheme.accent,
                        ),
                        Center(
                          child: Text(
                            '${_recoverySecondsLeft}s',
                            style: AppTheme.heading(fontSize: 36, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Measuring HR Recovery',
                      style: AppTheme.heading(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Keep your sensor on — stay still',
                      style: AppTheme.body(fontSize: 13, color: AppTheme.textMuted)),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () => setState(() => _showRecoveryOverlay = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.textMuted),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Skip',
                          style: AppTheme.body(fontSize: 14, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    ],
    ),
  );
  }

  // ── 7.1 Solo Interval Panel ──
  Widget _buildSoloIntervalPanel() {
    final phaseColor = _isWorkPhase ? const Color(0xFF22C55E) : const Color(0xFF8B5CF6);
    final phaseLabel = _isWorkPhase ? 'WORK' : 'REST';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _soloIntervalActive
              ? phaseColor.withValues(alpha: 0.1)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _soloIntervalActive
                ? phaseColor.withValues(alpha: 0.5)
                : AppTheme.surfaceLight,
          ),
        ),
        child: _soloIntervalActive
            ? Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: phaseColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(phaseLabel,
                        style: AppTheme.mono(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: phaseColor, letterSpacing: 2,
                        )),
                  ),
                  const Spacer(),
                  Text(
                    _intervalRemaining.toString().padLeft(2, '0'),
                    style: AppTheme.heading(
                      fontSize: 28, fontWeight: FontWeight.w700,
                      color: phaseColor,
                    ),
                  ),
                  Text('s',
                      style: AppTheme.body(fontSize: 14, color: phaseColor)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _stopSoloInterval,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close, size: 18, color: AppTheme.danger),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: AppTheme.textMuted),
                  const SizedBox(width: 8),
                  Text('INTERVAL',
                      style: AppTheme.mono(
                        fontSize: 10, letterSpacing: 1.5,
                        color: AppTheme.textMuted,
                      )),
                  const Spacer(),
                  // Preset buttons
                  _intervalPresetChip('20/10', 20, 10),
                  const SizedBox(width: 6),
                  _intervalPresetChip('40/20', 40, 20),
                  const SizedBox(width: 6),
                  _intervalPresetChip('60/30', 60, 30),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _startSoloInterval,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppTheme.accent, AppTheme.accentDark]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('GO',
                          style: AppTheme.mono(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: Colors.white, letterSpacing: 1,
                          )),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _intervalPresetChip(String label, int work, int rest) {
    final sel = _soloWorkSeconds == work && _soloRestSeconds == rest;
    return GestureDetector(
      onTap: () => setState(() {
        _soloWorkSeconds = work;
        _soloRestSeconds = rest;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: sel ? AppTheme.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: sel ? AppTheme.accent : AppTheme.surfaceLight,
          ),
        ),
        child: Text(label,
            style: AppTheme.mono(
              fontSize: 9, fontWeight: FontWeight.w600,
              color: sel ? AppTheme.accent : AppTheme.textMuted,
            )),
      ),
    );
  }

  Widget _buildMetricTile(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: AppTheme.metricCard(accentColor: color, borderRadius: 14),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color.withValues(alpha: 0.7)),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTheme.mono(fontSize: 9, letterSpacing: 1, color: AppTheme.textMuted)),
                Text(value,
                    style: AppTheme.heading(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveZoneBar() {
    if (_dataPoints.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 8,
          child: Container(color: AppTheme.surfaceLight),
        ),
      );
    }

    // Calculate zone time from data points
    final zoneCounts = <int, int>{};
    for (final dp in _dataPoints) {
      zoneCounts[dp.zone] = (zoneCounts[dp.zone] ?? 0) + 1;
    }
    final total = _dataPoints.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 20,
        child: Row(
          children: List.generate(5, (i) {
            final zone = i + 1;
            final count = zoneCounts[zone] ?? 0;
            final pct = total > 0 ? count / total : 0.0;
            if (pct <= 0) {
              return Expanded(
                flex: 1,
                child: Container(color: AppTheme.surfaceLight),
              );
            }
            return Expanded(
              flex: (pct * 100).round().clamp(1, 100),
              child: Container(
                color: HrZones.colors[zone],
                child: pct > 0.1
                    ? Center(
                        child: Text('Z$zone',
                            style: AppTheme.mono(
                              fontSize: 8, fontWeight: FontWeight.w700,
                              color: Colors.white, letterSpacing: 0,
                            )),
                      )
                    : null,
              ),
            );
          }),
        ),
      ),
    );
  }

  int _estimateCalories() {
    if (_bpmCount == 0) return 0;
    final avgHr = _totalBpm / _bpmCount;
    final minutes = _elapsed.inSeconds / 60;
    final weight = widget.profile.weightKg;
    final age = widget.profile.age;

    // Use gender-aware Keytel formula (same as AnalyticsEngine)
    if (widget.profile.sex == Sex.female) {
      return (minutes * (-20.4022 + (0.4472 * avgHr) - (0.1263 * weight) + (0.074 * age)) / 4.184)
          .round().clamp(0, 9999);
    } else {
      return (minutes * (-55.0969 + (0.6309 * avgHr) + (0.1988 * weight) + (0.2017 * age)) / 4.184)
          .round().clamp(0, 9999);
    }
  }

  Widget _buildHrChart() {
    if (_chartSpots.length < 2) {
      return Center(
        child: Text('Collecting data...',
            style: AppTheme.body(color: AppTheme.textMuted)),
      );
    }

    final hrMax = widget.profile.hrMax.toDouble();
    final minY = 40.0;
    final maxY = hrMax + 10;

    // Build zone band annotations (3.5)
    final zoneBands = <HorizontalRangeAnnotation>[];
    final zoneBoundaries = [
      (min: minY, max: hrMax * 0.60, zone: 1),
      (min: hrMax * 0.60, max: hrMax * 0.70, zone: 2),
      (min: hrMax * 0.70, max: hrMax * 0.80, zone: 3),
      (min: hrMax * 0.80, max: hrMax * 0.90, zone: 4),
      (min: hrMax * 0.90, max: maxY, zone: 5),
    ];
    for (final band in zoneBoundaries) {
      final color = HrZones.colors[band.zone] ?? Colors.grey;
      zoneBands.add(HorizontalRangeAnnotation(
        y1: band.min,
        y2: band.max,
        color: color.withValues(alpha: 0.06),
      ));
    }

    // Build lap marker vertical lines (3.4)
    final lapLines = _lapMarkers.map((lapElapsed) {
      return VerticalLine(
        x: lapElapsed.inSeconds.toDouble(),
        color: AppTheme.accent.withValues(alpha: 0.7),
        strokeWidth: 1.5,
        dashArray: [4, 4],
        label: VerticalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          style: AppTheme.mono(fontSize: 8, color: AppTheme.accent, fontWeight: FontWeight.w700),
          labelResolver: (_) => 'LAP',
        ),
      );
    }).toList();

    return LineChart(
      LineChartData(
        rangeAnnotations: RangeAnnotations(
          horizontalRangeAnnotations: zoneBands,
        ),
        extraLinesData: ExtraLinesData(verticalLines: lapLines),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (v) =>
              FlLine(color: AppTheme.surfaceLight.withValues(alpha: 0.6), strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 32, interval: 20,
              getTitlesWidget: (v, _) => Text('${v.toInt()}',
                  style: AppTheme.mono(color: AppTheme.textMuted, fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 20,
              interval: _elapsed.inSeconds > 600 ? 300 : 60,
              getTitlesWidget: (v, _) => Text('${(v / 60).floor()}m',
                  style: AppTheme.mono(color: AppTheme.textMuted, fontSize: 9)),
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: _chartSpots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: AppTheme.accent,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.accent.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
        minY: minY,
        maxY: maxY,
        lineTouchData: const LineTouchData(enabled: false),
      ),
      duration: const Duration(milliseconds: 150),
    );
  }
}

// ═══════════════════════════════════════════════════
// CIRCULAR HR GAUGE — CustomPainter
// ═══════════════════════════════════════════════════

class _HrGaugePainter extends CustomPainter {
  final double progress; // 0.0 → 1.0
  final Color zoneColor;

  _HrGaugePainter({required this.progress, required this.zoneColor});

  static const _startAngle = 2.356; // ~135° — 7:30 position
  static const _sweepAngle = 4.712; // ~270° — sweeps to 4:30 position
  static const _strokeWidth = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - _strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // ── Background track ──
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.surfaceLight;

    canvas.drawArc(rect, _startAngle, _sweepAngle, false, bgPaint);

    // ── Gradient foreground ──
    if (progress > 0.01) {
      final currentSweep = _sweepAngle * progress;

      final gradient = SweepGradient(
        startAngle: _startAngle,
        endAngle: _startAngle + _sweepAngle,
        colors: const [
          Color(0xFF3B82F6),
          Color(0xFF22C55E),
          Color(0xFFEAB308),
          Color(0xFFF97316),
          Color(0xFFEF4444),
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      );

      final fgPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = gradient.createShader(rect);

      canvas.drawArc(rect, _startAngle, currentSweep, false, fgPaint);

      // ── Glow dot at current position ──
      final dotAngle = _startAngle + currentSweep;
      final dotPos = Offset(
        center.dx + radius * math.cos(dotAngle),
        center.dy + radius * math.sin(dotAngle),
      );

      // Outer glow
      canvas.drawCircle(
        dotPos, 10,
        Paint()..color = zoneColor.withValues(alpha: 0.3),
      );
      // Inner dot
      canvas.drawCircle(
        dotPos, 5,
        Paint()..color = zoneColor,
      );
      // White center
      canvas.drawCircle(
        dotPos, 2.5,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_HrGaugePainter old) =>
      old.progress != progress || old.zoneColor != zoneColor;
}
