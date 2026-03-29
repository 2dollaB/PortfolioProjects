import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../config/hr_zones.dart';
import '../config/theme.dart';
import '../models/workout.dart';
import '../models/workout_type.dart';
import '../services/storage_service.dart';
import '../widgets/activity_calendar.dart';
import 'trends_screen.dart';
import 'workout_summary_screen.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  List<Workout> _workouts = [];
  bool _loading = true;
  int _streak = 0;
  ({int sessions, int minutes, int calories, int trimp})? _weeklyStats;

  // 8.6 — Search & Filter
  String _searchQuery = '';
  WorkoutType? _filterType;
  bool _showCalendar = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final workouts = await StorageService.loadWorkouts();
    final streak = await StorageService.calculateStreak();
    final stats = await StorageService.weeklyStats();
    setState(() {
      _workouts = workouts;
      _streak = streak;
      _weeklyStats = stats;
      _loading = false;
    });
  }

  /// 8.6 — Filtered workouts based on search + type filter (UX-6: date, calories, duration)
  List<Workout> get _filteredWorkouts {
    var list = _workouts;
    if (_filterType != null) {
      list = list.where((w) => w.workoutType == _filterType).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((w) {
        final typeName = w.workoutType.displayName.toLowerCase();
        final notes = (w.notes ?? '').toLowerCase();
        final dateStr = _formatDate(w.startTime).toLowerCase();
        final cals = '${w.analytics.calories.round()} cal';
        final dur = _formatDuration(w.duration);
        return typeName.contains(q) || notes.contains(q) ||
            dateStr.contains(q) || cals.contains(q) || dur.contains(q);
      }).toList();
    }
    return list;
  }

  Widget _buildSearchFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          // Search bar
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: AppTheme.body(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search workouts...',
              hintStyle: AppTheme.body(fontSize: 13, color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textMuted),
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          // Type filter chips
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip('All', null),
                ...WorkoutType.values.map((t) => _filterChip(t.displayName, t)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, WorkoutType? type) {
    final sel = _filterType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _filterType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: sel ? AppTheme.accent.withValues(alpha: 0.15) : AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: sel ? AppTheme.accent : AppTheme.surfaceLight),
          ),
          child: Text(label,
              style: AppTheme.mono(fontSize: 9, fontWeight: FontWeight.w600,
                  color: sel ? AppTheme.accent : AppTheme.textMuted)),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  String _formatDate(DateTime dt) {
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month]} ${dt.year} · $hour:$min';
  }

  // ══════════════════════════════════════════════
  // 4.5  CSV EXPORT
  // ══════════════════════════════════════════════

  Future<void> _exportCsv() async {
    HapticFeedback.mediumImpact();
    if (_workouts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No workouts to export')),
      );
      return;
    }

    final sb = StringBuffer();
    // Header
    sb.writeln(
      'id,date,type,duration_min,avg_hr,max_hr,min_hr,'
      'calories,trimp,training_effect,hr_recovery,laps',
    );
    // Rows
    for (final w in _workouts) {
      final a = w.analytics;
      sb.writeln([
        w.id,
        w.startTime.toIso8601String(),
        w.workoutType.name,
        w.duration.inMinutes,
        a.avgHr,
        a.maxHr,
        a.minHr,
        a.calories.round(),
        a.trimp.toStringAsFixed(1),
        a.trainingEffect.toStringAsFixed(2),
        a.hrRecovery,
        w.lapMarkers.length,
      ].join(','));
    }

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/beatsync_history.csv');
      await file.writeAsString(sb.toString());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'BeatSync Workout History',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Workout History',
            style: AppTheme.heading(fontSize: 20, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // 8.6 Calendar toggle
          IconButton(
            icon: Icon(_showCalendar ? Icons.list_rounded : Icons.calendar_month_rounded,
                color: AppTheme.accent),
            onPressed: () => setState(() => _showCalendar = !_showCalendar),
          ),
          // Trends nav
          IconButton(
            icon: const Icon(Icons.trending_up_rounded, color: AppTheme.accent),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TrendsScreen())),
          ),
          // CSV Export
          IconButton(
            icon: const Icon(Icons.ios_share_rounded, color: AppTheme.accent),
            onPressed: _exportCsv,
          ),
        ],
      ),
      body: _loading
          ? _buildSkeletonLoading()
          : _workouts.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppTheme.accent,
                  backgroundColor: AppTheme.surface,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // ── Weekly Stats Header (4.4) ──
                    if (_weeklyStats != null)
                      SliverToBoxAdapter(child: _buildWeeklyHeader()),

                    // ── 8.6 Search Bar + Filters ──
                    SliverToBoxAdapter(child: _buildSearchFilter()),

                    // ── 8.1 Calendar View (toggle) ──
                    if (_showCalendar)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: AppTheme.boldCard(),
                            child: ActivityCalendar(workouts: _workouts),
                          ),
                        ),
                      ),

                    // UX-5 — Filtered empty state
                    if (_filteredWorkouts.isEmpty && (_searchQuery.isNotEmpty || _filterType != null))
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.search_off, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.4)),
                                const SizedBox(height: 12),
                                Text('No results found',
                                    style: AppTheme.heading(fontSize: 17, color: AppTheme.textMuted)),
                                const SizedBox(height: 4),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No workouts matching "$_searchQuery"'
                                      : 'No ${_filterType?.displayName ?? ''} workouts',
                                  style: AppTheme.body(fontSize: 13, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // UX-6 — Result count
                    if (_filteredWorkouts.isNotEmpty && (_searchQuery.isNotEmpty || _filterType != null))
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Text(
                            '${_filteredWorkouts.length} result${_filteredWorkouts.length == 1 ? '' : 's'}',
                            style: AppTheme.mono(fontSize: 11, color: AppTheme.textMuted, letterSpacing: 0.5),
                          ),
                        ),
                      ),

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _buildWorkoutCard(_filteredWorkouts[index]),
                          childCount: _filteredWorkouts.length,
                        ),
                      ),
                    ),
                    ],
                  ),
                ),
    );
  }

  // ──────────────────────────────────────────────
  // 4.4 Weekly Stats + Streak Header
  // ──────────────────────────────────────────────
  Widget _buildWeeklyHeader() {
    final s = _weeklyStats!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: AppTheme.glowCard(color: AppTheme.accent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('THIS WEEK',
                          style: AppTheme.mono(
                            fontSize: 10, letterSpacing: 2,
                            color: AppTheme.textMuted, fontWeight: FontWeight.w600,
                          )),
                      const SizedBox(height: 4),
                      Text(
                        '${s.sessions} session${s.sessions == 1 ? '' : 's'}',
                        style: AppTheme.heading(fontSize: 20),
                      ),
                    ],
                  ),
                ),
                // Streak badge
                if (_streak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF97316), Color(0xFFEF4444)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text('🔥 $_streak',
                            style: AppTheme.heading(
                              fontSize: 18, fontWeight: FontWeight.w800,
                              color: Colors.white,
                            )),
                        Text('day streak',
                            style: AppTheme.mono(
                              fontSize: 9, color: Colors.white70, letterSpacing: 1,
                            )),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildWeeklyStat(Icons.schedule, '${s.minutes}', 'min'),
                _buildWeeklyStat(Icons.local_fire_department, '${s.calories}', 'kcal'),
                _buildWeeklyStat(Icons.timeline, '${s.trimp}', 'load'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyStat(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: AppTheme.accent.withValues(alpha: 0.8)),
          const SizedBox(height: 4),
          Text(value,
              style: AppTheme.heading(
                  fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          Text(label,
              style: AppTheme.mono(fontSize: 9, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  // UX-J — Skeleton loading
  Widget _buildSkeletonLoading() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(3, (i) => TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.3, end: 0.7),
          duration: Duration(milliseconds: 800 + i * 200),
          curve: Curves.easeInOut,
          builder: (_, opacity, __) => AnimatedOpacity(
            opacity: opacity,
            duration: const Duration(milliseconds: 400),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.surfaceLight),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 120, height: 12, decoration: BoxDecoration(
                      color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(width: 80, height: 10, decoration: BoxDecoration(
                      color: AppTheme.surfaceLight.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(4))),
                    const Spacer(),
                    Row(children: List.generate(4, (_) => Expanded(
                      child: Container(margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8, decoration: BoxDecoration(
                          color: AppTheme.surfaceLight.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(4))),
                    ))),
                  ],
                ),
              ),
            ),
          ),
        )),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.accent.withValues(alpha: 0.08),
            ),
            child: Icon(Icons.fitness_center,
                size: 56, color: AppTheme.textMuted.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          Text('No workouts yet',
              style: AppTheme.heading(
                  fontSize: 20, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Text(
            'Complete a workout to see it here',
            style: AppTheme.body(fontSize: 14, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // 4.1 Workout Card with type icon + lap count
  // ──────────────────────────────────────────────
  Widget _buildWorkoutCard(Workout workout) {
    final a = workout.analytics;
    final duration = workout.duration;

    // Find dominant zone
    int dominantZone = 1;
    Duration maxTime = Duration.zero;
    a.timeInZone.forEach((zone, time) {
      if (time > maxTime) {
        maxTime = time;
        dominantZone = zone;
      }
    });
    final zoneColor = HrZones.colors[dominantZone] ?? AppTheme.accent;

    return Dismissible(
      key: Key(workout.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(workout),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 28),
      ),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => WorkoutSummaryScreen(workout: workout)),
          ).then((_) => _loadData());
        },
        child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.glowCard(color: zoneColor),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: date + type badge + duration
            Row(
              children: [
                // Workout type icon (4.1)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: zoneColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(workout.workoutType.icon,
                      size: 16, color: zoneColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workout.workoutType.displayName,
                        style: AppTheme.body(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _formatDate(workout.startTime),
                        style: AppTheme.body(
                            fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                // Duration badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        zoneColor.withValues(alpha: 0.2),
                        zoneColor.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatDuration(duration),
                    style: AppTheme.mono(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: zoneColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Key metrics
            Row(
              children: [
                _buildMini(Icons.favorite, '${a.avgHr}', 'Avg', AppTheme.accent),
                _buildMini(Icons.arrow_upward, '${a.maxHr}', 'Max', HrZones.colors[5]!),
                _buildMini(Icons.local_fire_department, '${a.calories.round()}',
                    'kcal', const Color(0xFFF97316)),
                _buildMini(Icons.timeline, a.trimp.toStringAsFixed(0),
                    'TRIMP', const Color(0xFF8B5CF6)),
                // Lap count (4.1)
                if (workout.lapMarkers.isNotEmpty)
                  _buildMini(Icons.flag_rounded,
                      '${workout.lapMarkers.length}', 'Laps', AppTheme.accent),
                if (workout.lapMarkers.isEmpty)
                  _buildMini(Icons.trending_up, a.trainingEffect.toStringAsFixed(1),
                      'TE', const Color(0xFF06B6D4)),
              ],
            ),
            const SizedBox(height: 14),

            // Zone stacked bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: List.generate(5, (i) {
                    final zone = i + 1;
                    final pct = duration.inSeconds > 0
                        ? (a.timeInZone[zone]?.inSeconds ?? 0) /
                            duration.inSeconds
                        : 0.0;
                    return Expanded(
                      flex: (pct * 100).round().clamp(1, 100),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              HrZones.colors[zone]!,
                              HrZones.colors[zone]!.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    ),
    );
  }

  Future<bool> _confirmDelete(Workout workout) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Workout?', style: AppTheme.heading(fontSize: 18)),
        content: Text(
          'Remove this ${workout.workoutType.displayName} session?',
          style: AppTheme.body(fontSize: 14, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTheme.body(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Delete', style: AppTheme.body(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await StorageService.deleteWorkout(workout.id);
      _loadData();
      return true;
    }
    return false;
  }

  Widget _buildMini(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 14, color: color.withValues(alpha: 0.8)),
          const SizedBox(height: 3),
          Text(value,
              style: AppTheme.heading(
                  fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: AppTheme.mono(fontSize: 9, color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}
