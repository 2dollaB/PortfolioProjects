import 'dart:io';
import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../config/hr_zones.dart';
import '../config/theme.dart';
import '../models/workout.dart';
import '../services/storage_service.dart';
import '../widgets/hrv_chart.dart';

class WorkoutSummaryScreen extends StatefulWidget {
  final Workout workout;

  const WorkoutSummaryScreen({super.key, required this.workout});

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen> {
  List<String> _prs = [];

  // 7.3 / 7.4 — Post-workout rating
  late Workout _workout;
  int _rpe = 5;
  String _moodEmoji = '😊';
  final _notesController = TextEditingController();
  bool _ratingSaved = false;

  // UX-K — Scroll-to-top
  final ScrollController _scrollController = ScrollController();
  bool _showScrollTop = false;

  static const _moods = ['😤', '😐', '😊', '💪', '🔥'];

  @override
  void initState() {
    super.initState();
    _workout = widget.workout;
    _rpe = widget.workout.rpe ?? 5;
    _moodEmoji = widget.workout.moodEmoji ?? '😊';
    _notesController.text = widget.workout.notes ?? '';
    _loadPrs();
    _loadPreviousWorkout();

    // UX-K — Scroll-to-top listener
    _scrollController.addListener(() {
      final show = _scrollController.offset > 300;
      if (show != _showScrollTop) setState(() => _showScrollTop = show);
    });
  }

  /// Flatten RR intervals from all data points (8.4)
  List<int> get _rrIntervals => widget.workout.dataPoints
      .expand((dp) => dp.rrIntervals)
      .toList();

  @override
  void dispose() {
    _notesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _saveRating() async {
    _workout = _workout.copyWith(
      rpe: _rpe,
      moodEmoji: _moodEmoji,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );
    await StorageService.updateWorkout(_workout);
    if (mounted) setState(() => _ratingSaved = true);
  }

  Future<void> _shareWorkout() async {
    try {
      final a = widget.workout.analytics;
      final dur = widget.workout.duration;

      // Build a compact share card widget
      final card = MediaQuery(
        data: const MediaQueryData(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Container(
            width: 400, height: 520,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0A0A12), Color(0xFF1a1a2e), Color(0xFF16213e)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Title
                const Text('BeatSync', style: TextStyle(color: Color(0xFFE63946), fontFamily: 'SpaceGrotesk', fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 2, decoration: TextDecoration.none)),
                const SizedBox(height: 4),
                Text('WORKOUT COMPLETE', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontFamily: 'SpaceGrotesk', fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 3, decoration: TextDecoration.none)),
                const SizedBox(height: 20),
                // Duration
                Text(_formatDuration(dur), style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w200, letterSpacing: 4, fontFamily: 'Inter', decoration: TextDecoration.none)),
                const SizedBox(height: 6),
                // Workout type
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE63946).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(widget.workout.workoutType.displayName, style: const TextStyle(color: Color(0xFFE63946), fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'SpaceGrotesk', letterSpacing: 1, decoration: TextDecoration.none)),
                ),
                const SizedBox(height: 30),
                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _shareStatCol('CALORIES', '${a.calories.round()}', 'kcal', const Color(0xFFF97316)),
                    Container(width: 1, height: 50, color: Colors.white.withValues(alpha: 0.1)),
                    _shareStatCol('AVG HR', '${a.avgHr}', 'bpm', const Color(0xFFE63946)),
                    Container(width: 1, height: 50, color: Colors.white.withValues(alpha: 0.1)),
                    _shareStatCol('TRIMP', a.trimp.toStringAsFixed(0), 'load', const Color(0xFF8B5CF6)),
                  ],
                ),
                const SizedBox(height: 20),
                // Secondary row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _shareStatCol('MAX HR', '${a.maxHr}', 'bpm', const Color(0xFFEF4444)),
                    _shareStatCol('EFFECT', a.trainingEffect.toStringAsFixed(1), a.trainingEffectLabel, const Color(0xFF06B6D4)),
                    _shareStatCol('RECOVERY', a.hrRecovery > 0 ? '-${a.hrRecovery}' : '${a.hrRecovery}', 'bpm/60s', const Color(0xFF22C55E)),
                  ],
                ),
                const Spacer(),
                // Zone bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    height: 16,
                    child: Row(
                      children: List.generate(5, (i) {
                        final zone = i + 1;
                        final seconds = a.timeInZone[zone]?.inSeconds ?? 0;
                        if (seconds <= 0 || dur.inSeconds == 0) return const SizedBox.shrink();
                        return Expanded(
                          flex: (seconds * 10 ~/ dur.inSeconds).clamp(1, 1000),
                          child: Container(color: HrZones.colors[zone]),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('beatsync.app', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10, fontWeight: FontWeight.w400, fontFamily: 'Inter', decoration: TextDecoration.none)),
              ],
            ),
          ),
        ),
      );

      // Render to image
      final repaintBoundary = RenderRepaintBoundary();
      final renderView = RenderView(
        view: WidgetsBinding.instance.platformDispatcher.views.first,
        child: RenderPositionedBox(alignment: Alignment.center, child: repaintBoundary),
      );

      final pipelineOwner = PipelineOwner()..rootNode = renderView;
      renderView.prepareInitialFrame();

      final buildOwner = BuildOwner(focusManager: FocusManager());
      final element = RenderObjectToWidgetAdapter<RenderBox>(
        container: repaintBoundary,
        child: card,
      ).attachToRenderTree(buildOwner);

      buildOwner.buildScope(element);
      buildOwner.finalizeTree();
      pipelineOwner.flushLayout();
      pipelineOwner.flushCompositingBits();
      pipelineOwner.flushPaint();

      final image = await repaintBoundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/beatsync_workout.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Just completed a ${_formatDuration(dur)} ${widget.workout.workoutType.displayName} workout! 🔥 Avg HR: ${a.avgHr}bpm | ${a.calories.round()}kcal burned',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Widget _shareStatCol(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 8, fontWeight: FontWeight.w600, letterSpacing: 1.5, fontFamily: 'SpaceGrotesk', decoration: TextDecoration.none)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w700, fontFamily: 'Inter', decoration: TextDecoration.none)),
        Text(unit, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9, fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w400, decoration: TextDecoration.none)),
      ],
    );
  }


  Future<void> _loadPrs() async {
    final prs = await StorageService.checkPersonalRecords(widget.workout);
    if (mounted) setState(() => _prs = prs);
  }

  // Phase 2 — Load previous workout of same type for comparison
  Workout? _previousWorkout;
  Future<void> _loadPreviousWorkout() async {
    final all = await StorageService.loadWorkouts();
    final sameType = all.where((w) =>
        w.workoutType == widget.workout.workoutType &&
        w.id != widget.workout.id &&
        w.startTime.isBefore(widget.workout.startTime));
    if (sameType.isNotEmpty && mounted) {
      setState(() => _previousWorkout = sameType.first);
    }
  }

  /// Generate an AI-style insight based on workout data
  String _generateInsight() {
    final a = widget.workout.analytics;
    final duration = widget.workout.duration;

    // Determine dominant zone
    int dominantZone = 1;
    Duration maxTime = Duration.zero;
    a.timeInZone.forEach((zone, time) {
      if (time > maxTime) {
        maxTime = time;
        dominantZone = zone;
      }
    });
    final pct = duration.inSeconds > 0
        ? (maxTime.inSeconds / duration.inSeconds * 100).round()
        : 0;

    final zoneName = HrZones.names[dominantZone] ?? 'Zone $dominantZone';

    if (dominantZone <= 2) {
      return 'Great recovery session! You spent $pct% in $zoneName zone — perfect for aerobic base building and active recovery.';
    } else if (dominantZone == 3) {
      return 'Solid aerobic workout! $pct% in $zoneName zone strengthens your cardiovascular system and builds endurance.';
    } else if (dominantZone == 4) {
      return 'Intense threshold session! $pct% in $zoneName zone pushes your lactate threshold higher. Great for race fitness!';
    } else {
      return 'Maximum effort! $pct% in $zoneName zone. This boosts VO₂ Max but needs 48h+ recovery. Great work! 💪';
    }
  }

  /// Build a comparison string for a metric
  String? _comparisonText(double current, double previous) {
    if (previous <= 0) return null;
    final diff = ((current - previous) / previous * 100).round();
    if (diff == 0) return null;
    return diff > 0 ? '+$diff%' : '$diff%';
  }

  Color get _rpeColor {
    if (_rpe <= 3) return const Color(0xFF22C55E);
    if (_rpe <= 5) return const Color(0xFFEAB308);
    if (_rpe <= 7) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
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
    final a = widget.workout.analytics;
    final duration = widget.workout.duration;
    final prev = _previousWorkout?.analytics;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.3, 1.0],
            colors: [
              AppTheme.accent.withValues(alpha: 0.1),
              AppTheme.background.withValues(alpha: 0.95),
              AppTheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                controller: _scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ═══════════════════════════════════════
                // HERO: Zone Ring + Duration + Type
                // ═══════════════════════════════════════
                const SizedBox(height: 4),
                SizedBox(
                  width: 180, height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Zone distribution ring
                      SizedBox(
                        width: 180, height: 180,
                        child: _buildZonePieChart(duration),
                      ),
                      // Center content
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: duration.inSeconds.toDouble()),
                            duration: const Duration(milliseconds: 1200),
                            curve: Curves.easeOutCubic,
                            builder: (context, v, _) {
                              final d = Duration(seconds: v.toInt());
                              return Text(
                                _formatDuration(d),
                                style: AppTheme.heading(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w200,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(widget.workout.workoutType.icon, size: 12, color: AppTheme.accent),
                                const SizedBox(width: 4),
                                Text(
                                  widget.workout.workoutType.displayName,
                                  style: AppTheme.mono(fontSize: 10, color: AppTheme.accent, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text('Workout Complete!',
                    style: AppTheme.heading(fontSize: 20, fontWeight: FontWeight.w600)),

                // ═══════════════════════════════════════
                // PR BANNER
                // ═══════════════════════════════════════
                if (_prs.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFFD700).withValues(alpha: 0.15),
                          const Color(0xFFFFD700).withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Text('🏆', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Wrap(
                            spacing: 6, runSpacing: 4,
                            children: _prs.map((pr) => Text(
                              pr,
                              style: AppTheme.body(fontSize: 12, color: const Color(0xFFFFD700), fontWeight: FontWeight.w600),
                            )).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ═══════════════════════════════════════
                // INSIGHT CARD
                // ═══════════════════════════════════════
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.accent.withValues(alpha: 0.08),
                        AppTheme.surface,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.auto_awesome, size: 18, color: AppTheme.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _generateInsight(),
                          style: AppTheme.body(fontSize: 13, color: AppTheme.textSecondary).copyWith(height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),

                // ═══════════════════════════════════════
                // PRIMARY STATS (3 big cards)
                // ═══════════════════════════════════════
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildPrimaryStat(
                      'CALORIES', a.calories.round().toString(), 'kcal',
                      Icons.local_fire_department, const Color(0xFFF97316),
                      comparison: prev != null ? _comparisonText(a.calories, prev.calories) : null,
                    ),
                    const SizedBox(width: 8),
                    _buildPrimaryStat(
                      'AVG HR', '${a.avgHr}', 'bpm',
                      Icons.favorite, AppTheme.accent,
                      comparison: prev != null ? _comparisonText(a.avgHr.toDouble(), prev.avgHr.toDouble()) : null,
                    ),
                    const SizedBox(width: 8),
                    _buildPrimaryStat(
                      'TRIMP', a.trimp.toStringAsFixed(0), 'load',
                      Icons.timeline, const Color(0xFF8B5CF6),
                      comparison: prev != null ? _comparisonText(a.trimp, prev.trimp) : null,
                    ),
                  ],
                ),

                // ═══════════════════════════════════════
                // SECONDARY STATS (3 compact)
                // ═══════════════════════════════════════
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildSecondaryStat('Max HR', '${a.maxHr}', 'bpm', HrZones.colors[5]!),
                    const SizedBox(width: 8),
                    _buildSecondaryStat('Effect', a.trainingEffect.toStringAsFixed(1), a.trainingEffectLabel, const Color(0xFF06B6D4)),
                    const SizedBox(width: 8),
                    _buildSecondaryStat('Recovery', a.hrRecovery > 0 ? '-${a.hrRecovery}' : '${a.hrRecovery}', 'bpm/60s', const Color(0xFF22C55E)),
                  ],
                ),

                // ═══════════════════════════════════════
                // ZONE DISTRIBUTION
                // ═══════════════════════════════════════
                const SizedBox(height: 24),
                _buildSectionTitle('Zone Distribution', 'Time in each training zone'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.boldCard(),
                  child: Column(
                    children: [
                      _buildStackedZoneBar(duration),
                      const SizedBox(height: 14),
                      ...List.generate(5, (i) => _buildZoneRowExpanded(i + 1, duration)),
                    ],
                  ),
                ),

                // ═══════════════════════════════════════
                // LAPS
                // ═══════════════════════════════════════
                if (widget.workout.lapMarkers.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildSectionTitle('Laps', '${widget.workout.lapMarkers.length} recorded'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.boldCard(),
                    child: Column(
                      children: List.generate(widget.workout.lapMarkers.length, (i) {
                        final lapStart = i == 0 ? Duration.zero : widget.workout.lapMarkers[i - 1];
                        final lapEnd = widget.workout.lapMarkers[i];
                        final lapDuration = lapEnd - lapStart;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 26, height: 26,
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Center(
                                  child: Text('L${i + 1}',
                                      style: AppTheme.mono(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.accent)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text('Lap ${i + 1}', style: AppTheme.body(fontSize: 13, color: Colors.white))),
                              Text(_formatDuration(lapDuration),
                                  style: AppTheme.mono(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 10),
                              Text('at ${_formatDuration(lapEnd)}',
                                  style: AppTheme.mono(fontSize: 10, color: AppTheme.textMuted)),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ],

                // ═══════════════════════════════════════
                // HR TIMELINE
                // ═══════════════════════════════════════
                const SizedBox(height: 24),
                _buildSectionTitle('Heart Rate', 'Timeline over workout'),
                const SizedBox(height: 10),
                Container(
                  height: 200,
                  padding: const EdgeInsets.fromLTRB(0, 14, 14, 6),
                  decoration: AppTheme.boldCard(),
                  child: _buildHrTimeline(),
                ),

                // ═══════════════════════════════════════
                // HRV
                // ═══════════════════════════════════════
                if (_rrIntervals.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildSectionTitle('HRV', 'Beat-to-beat variability'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.boldCard(),
                    child: HrvChart(rrIntervals: _rrIntervals),
                  ),
                ],

                // ═══════════════════════════════════════
                // COMPACT RATE & NOTES
                // ═══════════════════════════════════════
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.boldCard(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mood row
                      Row(
                        children: [
                          Text('MOOD', style: AppTheme.mono(fontSize: 9, letterSpacing: 1.5, color: AppTheme.textMuted)),
                          const Spacer(),
                          Text('RPE  ', style: AppTheme.mono(fontSize: 9, letterSpacing: 1.5, color: AppTheme.textMuted)),
                          Text('$_rpe', style: AppTheme.heading(fontSize: 20, color: _rpeColor)),
                          Text('/10', style: AppTheme.body(fontSize: 11, color: AppTheme.textMuted)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Mood emojis — compact
                          ...(_moods.map((emoji) => GestureDetector(
                            onTap: () => setState(() => _moodEmoji = emoji),
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _moodEmoji == emoji ? AppTheme.accent.withValues(alpha: 0.15) : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _moodEmoji == emoji ? AppTheme.accent : AppTheme.surfaceLight,
                                  width: _moodEmoji == emoji ? 2 : 1,
                                ),
                              ),
                              child: Text(emoji, style: const TextStyle(fontSize: 18)),
                            ),
                          ))),
                          const Spacer(),
                          // RPE slider — compact
                          SizedBox(
                            width: 120,
                            child: SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: _rpeColor,
                                inactiveTrackColor: AppTheme.surfaceLight,
                                thumbColor: _rpeColor,
                                overlayColor: _rpeColor.withValues(alpha: 0.2),
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              ),
                              child: Slider(
                                value: _rpe.toDouble(), min: 1, max: 10, divisions: 9,
                                onChanged: (v) => setState(() => _rpe = v.round()),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Notes field
                      TextField(
                        controller: _notesController,
                        maxLines: 2,
                        style: AppTheme.body(fontSize: 13, color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Add notes...',
                          hintStyle: AppTheme.body(fontSize: 12, color: AppTheme.textMuted),
                          filled: true,
                          fillColor: AppTheme.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppTheme.surfaceLight),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppTheme.surfaceLight),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppTheme.accent),
                          ),
                          contentPadding: const EdgeInsets.all(10),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity, height: 36,
                        child: ElevatedButton(
                          onPressed: _ratingSaved ? null : _saveRating,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _ratingSaved ? AppTheme.surface : AppTheme.accent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            _ratingSaved ? '✓ Saved' : 'Save Rating',
                            style: AppTheme.body(
                              fontSize: 12,
                              color: _ratingSaved ? AppTheme.textMuted : Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ═══════════════════════════════════════
                // DONE BUTTON
                // ═══════════════════════════════════════
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _shareWorkout,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.surfaceLight),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                          label: Text('Share',
                              style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                          label: Text('Done',
                              style: AppTheme.heading(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
              // UX-K — Scroll-to-top FAB
              Positioned(
                right: 16,
                bottom: 24,
                child: AnimatedScale(
                  scale: _showScrollTop ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: FloatingActionButton.small(
                    backgroundColor: AppTheme.surface,
                    onPressed: () => _scrollController.animateTo(0,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic),
                    child: const Icon(Icons.keyboard_arrow_up_rounded,
                      color: AppTheme.accent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // PRIMARY STAT CARD (tall, prominent)
  // ═══════════════════════════════════════════
  Widget _buildPrimaryStat(String label, String value, String unit, IconData icon, Color color, {String? comparison}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) {
                final display = v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
                return Text(display, style: AppTheme.heading(fontSize: 26, fontWeight: FontWeight.w700, color: color));
              },
            ),
            Text(unit, style: AppTheme.mono(fontSize: 9, color: AppTheme.textMuted)),
            if (comparison != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: comparison.startsWith('+') ? AppTheme.success.withValues(alpha: 0.12) : AppTheme.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(comparison,
                    style: AppTheme.mono(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: comparison.startsWith('+') ? AppTheme.success : AppTheme.danger,
                    )),
              ),
            ],
            const SizedBox(height: 2),
            Text(label, style: AppTheme.mono(fontSize: 8, letterSpacing: 0.5, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // SECONDARY STAT CARD (compact row)
  // ═══════════════════════════════════════════
  Widget _buildSecondaryStat(String label, String value, String unit, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.surfaceLight),
        ),
        child: Column(
          children: [
            Text(value, style: AppTheme.heading(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
            Text(unit, style: AppTheme.mono(fontSize: 8, color: AppTheme.textMuted)),
            const SizedBox(height: 2),
            Text(label, style: AppTheme.mono(fontSize: 8, letterSpacing: 0.3, color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  // ── Zone Pie Chart (4.2) ──
  Widget _buildZonePieChart(Duration totalDuration) {
    if (totalDuration.inSeconds == 0) return const SizedBox.shrink();
    final sections = <PieChartSectionData>[];
    for (int zone = 1; zone <= 5; zone++) {
      final seconds =
          widget.workout.analytics.timeInZone[zone]?.inSeconds ?? 0;
      if (seconds <= 0) continue;
      final pct = seconds / totalDuration.inSeconds * 100;
      sections.add(PieChartSectionData(
        value: pct,
        color: HrZones.colors[zone]!,
        radius: 18,
        showTitle: false,
      ));
    }
    if (sections.isEmpty) return const SizedBox.shrink();
    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 28,
        sectionsSpace: 2,
        startDegreeOffset: -90,
      ),
    );
  }

  // ── Stacked Horizontal Zone Bar ──
  Widget _buildStackedZoneBar(Duration totalDuration) {
    final percentages = widget.workout.analytics.zonePercentages(totalDuration);
    final totalSeconds = totalDuration.inSeconds;
    if (totalSeconds == 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 28,
        child: Row(
          children: List.generate(5, (index) {
            final zone = index + 1;
            final pct = percentages[zone] ?? 0;
            if (pct <= 0) return const SizedBox.shrink();
            return Expanded(
              flex: (pct * 10).round().clamp(1, 1000),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      HrZones.colors[zone]!,
                      HrZones.colors[zone]!.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: pct > 10
                    ? Center(
                        child: Text(
                          '${pct.round()}%',
                          style: AppTheme.mono(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : null,
              ),
            );
          }),
        ),
      ),
    );
  }


  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(title,
              style: AppTheme.heading(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: AppTheme.body(fontSize: 12, color: AppTheme.textMuted)),
      ],
    );
  }

  Widget _buildHrTimeline() {
    if (widget.workout.dataPoints.isEmpty) {
      return Center(
          child: Text('No data', style: AppTheme.body(color: AppTheme.textMuted)));
    }

    final points = _downsample(widget.workout.dataPoints, 150);
    final startTime = widget.workout.startTime;

    final spots = points.map((dp) {
      final seconds = dp.timestamp.difference(startTime).inSeconds.toDouble();
      return FlSpot(seconds, dp.bpm.toDouble());
    }).toList();

    if (spots.length < 2) {
      return Center(
          child: Text('Not enough data', style: AppTheme.body(color: AppTheme.textMuted)));
    }

    final maxSeconds = widget.workout.duration.inSeconds.toDouble();

    // Lap marker vertical lines
    final lapLines = widget.workout.lapMarkers.map((lapElapsed) {
      return VerticalLine(
        x: lapElapsed.inSeconds.toDouble(),
        color: AppTheme.accent.withValues(alpha: 0.6),
        strokeWidth: 1.5,
        dashArray: [4, 4],
        label: VerticalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          style: AppTheme.mono(
              fontSize: 8, color: AppTheme.accent, fontWeight: FontWeight.w700),
          labelResolver: (_) => 'LAP',
        ),
      );
    }).toList();

    return LineChart(
      LineChartData(
        extraLinesData: ExtraLinesData(verticalLines: lapLines),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: AppTheme.surfaceLight.withValues(alpha: 0.5), strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              interval: 20,
              getTitlesWidget: (value, _) => Text(
                '${value.toInt()}',
                style: AppTheme.mono(color: AppTheme.textMuted, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: maxSeconds > 600 ? 300 : 60,
              getTitlesWidget: (value, _) {
                final min = (value / 60).floor();
                return Text('${min}m',
                    style: AppTheme.mono(color: AppTheme.textMuted, fontSize: 10));
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF3B82F6),
                Color(0xFF22C55E),
                Color(0xFFFACC15),
                Color(0xFFF97316),
                Color(0xFFEF4444),
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
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
          // Avg HR dashed line
          LineChartBarData(
            spots: [
              FlSpot(0, widget.workout.analytics.avgHr.toDouble()),
              FlSpot(maxSeconds, widget.workout.analytics.avgHr.toDouble()),
            ],
            isCurved: false,
            color: AppTheme.accent.withValues(alpha: 0.4),
            barWidth: 1,
            dashArray: [5, 5],
            dotData: const FlDotData(show: false),
          ),
        ],
        minY: 40,
        maxY: (widget.workout.analytics.hrMax + 10).toDouble(),
        lineTouchData: const LineTouchData(enabled: false),
      ),
    );
  }

  // ── Expanded Zone Row with time, percentage, and mini bar ──
  Widget _buildZoneRowExpanded(int zone, Duration totalDuration) {
    final color = HrZones.colors[zone]!;
    final name = HrZones.names[zone] ?? '';
    final timeInZone = widget.workout.analytics.timeInZone[zone] ?? Duration.zero;
    final pct = totalDuration.inSeconds > 0
        ? (timeInZone.inSeconds / totalDuration.inSeconds * 100)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Text('Z$zone',
                  style: AppTheme.mono(
                      fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTheme.body(
                        fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    height: 4,
                    child: LinearProgressIndicator(
                      value: (pct / 100).clamp(0.0, 1.0),
                      backgroundColor: AppTheme.surfaceLight,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_formatDuration(timeInZone),
                  style: AppTheme.mono(fontSize: 11, color: AppTheme.textSecondary)),
              Text('${pct.round()}%',
                  style: AppTheme.mono(
                      fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ],
      ),
    );
  }


  List<HrDataPoint> _downsample(List<HrDataPoint> data, int maxPoints) {
    if (data.length <= maxPoints) return data;
    final step = data.length / maxPoints;
    return List.generate(maxPoints, (i) => data[(i * step).floor()]);
  }
}
