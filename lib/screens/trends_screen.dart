import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../config/hr_zones.dart';
import '../config/theme.dart';
import '../models/workout.dart';
import '../services/storage_service.dart';
import '../services/workout_stats_service.dart';
import '../widgets/activity_calendar.dart';

/// 8.1 / 8.5 — Trends & Analytics Screen.
///
/// Descriptive only: it reports what happened in the studio (sessions,
/// minutes, BeatPoints, zone time) and makes no claims about form, readiness,
/// or injury risk. No load model, no ACWR — those are not defensible here.
class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});
  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  List<Workout> _workouts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final w = await StorageService.loadWorkouts();
    if (mounted) setState(() { _workouts = w; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Trends', style: AppTheme.heading(fontSize: 20)),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2))
          : _workouts.isEmpty
              ? Center(child: Text('Complete some workouts first!',
                  style: AppTheme.body(color: AppTheme.textMuted)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 8.1 Activity Calendar ──
                      _sectionTitle('Activity', '6 months'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AppTheme.boldCard(),
                        child: ActivityCalendar(workouts: _workouts),
                      ),
                      const SizedBox(height: 24),

                      // ── Sessions per week ──
                      _sectionTitle('Sessions', '8 weeks'),
                      const SizedBox(height: 12),
                      Container(
                        height: 160,
                        padding: const EdgeInsets.fromLTRB(0, 16, 16, 8),
                        decoration: AppTheme.boldCard(),
                        child: _buildIntBarChart(
                          WorkoutStatsService.weeklySessions(_workouts),
                          color: const Color(0xFF8B5CF6),
                          unit: '',
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Minutes per week ──
                      _sectionTitle('Minutes', '8 weeks'),
                      const SizedBox(height: 12),
                      Container(
                        height: 160,
                        padding: const EdgeInsets.fromLTRB(0, 16, 16, 8),
                        decoration: AppTheme.boldCard(),
                        child: _buildIntBarChart(
                          WorkoutStatsService.weeklyMinutes(_workouts),
                          color: const Color(0xFF3B82F6),
                          unit: 'min',
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Weekly BeatPoints ──
                      _sectionTitle('BeatPoints', '8 weeks'),
                      const SizedBox(height: 12),
                      Container(
                        height: 200,
                        padding: const EdgeInsets.fromLTRB(0, 16, 16, 8),
                        decoration: AppTheme.boldCard(),
                        child: _buildIntBarChart(
                          WorkoutStatsService.weeklyBeatPoints(_workouts),
                          color: AppTheme.accent,
                          unit: 'BeatPoints',
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── 8.5 Zone Distribution Over Time ──
                      _sectionTitle('Zone Distribution', '8 weeks'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AppTheme.boldCard(),
                        child: _buildZoneDistribution(),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _sectionTitle(String title, String sub) {
    return Row(
      children: [
        Text(title, style: AppTheme.heading(fontSize: 16)),
        const Spacer(),
        Text(sub, style: AppTheme.mono(fontSize: 10, color: AppTheme.textMuted, letterSpacing: 1)),
      ],
    );
  }

  // ── Weekly integer bar chart (sessions / minutes / BeatPoints) ──
  Widget _buildIntBarChart(List<int> data, {required Color color, required String unit}) {
    final maxData = data.isEmpty ? 0 : data.reduce(math.max);
    final maxY = maxData <= 0 ? 5.0 : maxData.toDouble() + (maxData * 0.15).ceilToDouble() + 1;
    final suffix = unit.isEmpty ? '' : ' $unit';

    return BarChart(BarChartData(
      maxY: maxY,
      barGroups: List.generate(data.length, (i) => BarChartGroupData(
        x: i,
        barRods: [BarChartRodData(
          toY: data[i].toDouble(),
          width: 16,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          gradient: LinearGradient(
            begin: Alignment.bottomCenter, end: Alignment.topCenter,
            colors: [color.withValues(alpha: 0.4), color],
          ),
        )],
      )),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (v, _) => Text(
            'W${v.toInt() + 1}',
            style: AppTheme.mono(fontSize: 8, color: AppTheme.textMuted),
          ),
        )),
      ),
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: false),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, gIdx, rod, rIdx) => BarTooltipItem(
            '${rod.toY.round()}$suffix',
            AppTheme.mono(fontSize: 10, color: Colors.white),
          ),
        ),
      ),
    ));
  }

  // ── 8.5 Zone Distribution Stacked Bars ──
  Widget _buildZoneDistribution() {
    final data = WorkoutStatsService.weeklyZoneDistribution(_workouts);
    if (data.every((m) => m.isEmpty)) {
      return Center(child: Text('No zone data', style: AppTheme.body(color: AppTheme.textMuted)));
    }
    return Column(
      children: List.generate(data.length, (weekIdx) {
        final week = data[weekIdx];
        if (week.isEmpty) return const SizedBox(height: 18);
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              SizedBox(width: 28,
                child: Text('W${weekIdx + 1}',
                    style: AppTheme.mono(fontSize: 8, color: AppTheme.textMuted))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: SizedBox(
                    height: 14,
                    child: Row(
                      children: List.generate(5, (z) {
                        final zone = z + 1;
                        final pct = week[zone] ?? 0;
                        if (pct <= 0) return const SizedBox.shrink();
                        return Expanded(
                          flex: (pct * 10).round().clamp(1, 1000),
                          child: Container(color: HrZones.colors[zone]),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
