import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../config/hr_zones.dart';
import '../config/theme.dart';
import '../models/user_profile.dart';
import '../models/workout.dart';
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

  const WorkoutScreen({
    super.key,
    required this.profile,
    required this.bleService,
    this.tvServer,
    this.sessionClient,
  });

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  // Workout state
  bool _isPaused = false;
  late DateTime _startTime;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  // HR data
  final List<HrDataPoint> _dataPoints = [];
  final List<FlSpot> _chartSpots = [];
  int _currentBpm = 0;
  int _currentZone = 0;
  int _maxBpm = 0;
  int _totalBpm = 0;
  int _bpmCount = 0;

  // Subscriptions
  StreamSubscription? _hrSub;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _startTimer();
    _listenToHr();
    // Keep app alive in background
    startForegroundService();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPaused) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime);
        });
      }
    });
  }

  void _listenToHr() {
    _hrSub = widget.bleService.hrDataStream.listen((data) {
      if (_isPaused) return;

      final zone = HrZones.fromBpm(data.bpm, widget.profile.hrMax);
      final now = DateTime.now();

      // Update dynamic HRmax if exceeded
      widget.profile.updateDynamicHrMax(data.bpm);

      setState(() {
        _currentBpm = data.bpm;
        _currentZone = zone;
        if (data.bpm > _maxBpm) _maxBpm = data.bpm;
        _totalBpm += data.bpm;
        _bpmCount++;

        // Record data point
        _dataPoints.add(HrDataPoint(
          bpm: data.bpm,
          zone: zone,
          timestamp: now,
        ));

        // Update chart (seconds since start → BPM)
        final secondsSinceStart = now.difference(_startTime).inSeconds.toDouble();
        _chartSpots.add(FlSpot(secondsSinceStart, data.bpm.toDouble()));

        // Keep max 600 chart points (10 min at 1/sec) for performance
        if (_chartSpots.length > 600) {
          _chartSpots.removeAt(0);
        }
      });

      // Send to TV server if running (host mode)
      if (widget.tvServer != null && widget.tvServer!.isRunning) {
        widget.tvServer!.updateUserHr(
          userId: widget.profile.name,
          name: widget.profile.name,
          bpm: data.bpm,
          zone: zone,
          hrMax: widget.profile.hrMax,
        );
      }

      // Send to session hub if connected (participant mode)
      if (widget.sessionClient != null && widget.sessionClient!.isConnected) {
        widget.sessionClient!.sendHrUpdate(
          userId: widget.profile.name,
          name: widget.profile.name,
          bpm: data.bpm,
          zone: zone,
          hrMax: widget.profile.hrMax,
        );
      }

      // Update notification with current BPM
      updateForegroundNotification('${data.bpm} BPM — Zone $zone');
    });
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
  }

  Future<void> _stopWorkout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End Workout?'),
        content: const Text('Your workout data will be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Workout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _timer?.cancel();

      // Stop foreground service
      stopForegroundService();

      // Remove from TV
      widget.tvServer?.removeUser(widget.profile.name);
      // Notify hub if participant
      widget.sessionClient?.sendRemove(widget.profile.name);

      // Calculate analytics
      final analytics = AnalyticsEngine.calculate(
        dataPoints: _dataPoints,
        profile: widget.profile,
        totalDuration: _elapsed,
      );

      // Create workout
      final workout = Workout(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: _startTime,
        endTime: DateTime.now(),
        dataPoints: _dataPoints,
        analytics: analytics,
      );

      // Save
      await StorageService.saveWorkout(workout);
      await StorageService.saveProfile(widget.profile); // Save updated dynamic HRmax

      if (!mounted) return;

      // Navigate to summary
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WorkoutSummaryScreen(workout: workout),
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hrSub?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final zoneColor = HrZones.colors[_currentZone] ?? Colors.grey;
    final zoneName = HrZones.names[_currentZone] ?? 'Rest';
    final avgHr = _bpmCount > 0 ? (_totalBpm / _bpmCount).round() : 0;
    final pctOfMax = HrZones.percentOfMax(_currentBpm, widget.profile.hrMax);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stopWorkout();
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                zoneColor.withValues(alpha: 0.15),
                AppTheme.background,
                AppTheme.background,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // ── Top Stats Bar ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStat('TIME', _formatDuration(_elapsed), Colors.white),
                      _buildStat('AVG HR', '$avgHr', AppTheme.accentLight),
                      _buildStat('MAX HR', '$_maxBpm', HrZones.colors[5]!),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Zone Pill ──
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey(_currentZone),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    decoration: BoxDecoration(
                      color: zoneColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: zoneColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      'Zone $_currentZone · $zoneName · $pctOfMax%',
                      style: TextStyle(color: zoneColor, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Big BPM ──
                Text(
                  _currentBpm > 0 ? '$_currentBpm' : '--',
                  style: TextStyle(
                    fontSize: 88,
                    fontWeight: FontWeight.w200,
                    color: Colors.white,
                    height: 1,
                    shadows: [Shadow(color: zoneColor.withValues(alpha: 0.5), blurRadius: 30)],
                  ),
                ),
                Text('BPM',
                    style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, letterSpacing: 3)),

                const SizedBox(height: 16),

                // ── Mini HR Chart ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildHrChart(zoneColor),
                  ),
                ),

                // ── Zone Bar ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildZoneBar(),
                ),

                const SizedBox(height: 20),

                // ── Controls ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Pause/Resume
                      _buildControlButton(
                        icon: _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        label: _isPaused ? 'Resume' : 'Pause',
                        color: AppTheme.accent,
                        onTap: _togglePause,
                      ),
                      // Stop
                      _buildControlButton(
                        icon: Icons.stop_rounded,
                        label: 'Stop',
                        color: HrZones.colors[5]!,
                        onTap: _stopWorkout,
                        large: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted, letterSpacing: 1, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _buildHrChart(Color zoneColor) {
    if (_chartSpots.length < 2) {
      return Center(
        child: Text('Collecting data...', style: TextStyle(color: AppTheme.textMuted)),
      );
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppTheme.surfaceLight,
            strokeWidth: 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              interval: 20,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
              ),
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: _chartSpots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: zoneColor,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  zoneColor.withValues(alpha: 0.3),
                  zoneColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
        minY: 40,
        maxY: (widget.profile.hrMax + 10).toDouble(),
        lineTouchData: const LineTouchData(enabled: false),
      ),
      duration: const Duration(milliseconds: 150),
    );
  }

  Widget _buildZoneBar() {
    return Row(
      children: List.generate(5, (index) {
        final zone = index + 1;
        final isActive = zone == _currentZone;
        final color = HrZones.colors[zone]!;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: isActive ? 24 : 12,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: isActive ? color : color.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(6),
              boxShadow: isActive
                  ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)]
                  : [],
            ),
            child: isActive
                ? Center(child: Text('Z$zone', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)))
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool large = false,
  }) {
    final size = large ? 72.0 : 60.0;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.2),
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: large ? 36 : 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
