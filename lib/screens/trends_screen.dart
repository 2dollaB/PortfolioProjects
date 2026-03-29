import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../config/hr_zones.dart';
import '../config/theme.dart';
import '../models/workout.dart';
import '../services/storage_service.dart';
import '../services/training_load_service.dart';
import '../widgets/activity_calendar.dart';

/// 8.2 / 8.3 / 8.5 — Trends & Analytics Screen
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
                      // ── 8.3 Training Load Gauge ──
                      _buildAcwrSection(),
                      const SizedBox(height: 24),

                      // ── 8.1 Activity Calendar ──
                      _sectionTitle('Activity', '6 months'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AppTheme.boldCard(),
                        child: ActivityCalendar(workouts: _workouts),
                      ),
                      const SizedBox(height: 24),

                      // ── 8.2 Weekly TRIMP Trend ──
                      _sectionTitle('Weekly Load', '8 weeks'),
                      const SizedBox(height: 12),
                      Container(
                        height: 200,
                        padding: const EdgeInsets.fromLTRB(0, 16, 16, 8),
                        decoration: AppTheme.boldCard(),
                        child: _buildTrimpChart(),
                      ),
                      const SizedBox(height: 24),

                      // ── 8.2 Weekly Avg HR ──
                      _sectionTitle('Average Heart Rate', '8 weeks'),
                      const SizedBox(height: 12),
                      Container(
                        height: 200,
                        padding: const EdgeInsets.fromLTRB(0, 16, 16, 8),
                        decoration: AppTheme.boldCard(),
                        child: _buildAvgHrChart(),
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

                      // ── 8.2 Sessions Per Week ──
                      _sectionTitle('Sessions', '8 weeks'),
                      const SizedBox(height: 12),
                      Container(
                        height: 160,
                        padding: const EdgeInsets.fromLTRB(0, 16, 16, 8),
                        decoration: AppTheme.boldCard(),
                        child: _buildSessionsChart(),
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

  // ── 8.3 ACWR Gauge ──
  Widget _buildAcwrSection() {
    final acute = TrainingLoadService.acuteLoad(_workouts);
    final chronic = TrainingLoadService.chronicLoad(_workouts);
    final ratio = TrainingLoadService.acwr(_workouts);
    final status = TrainingLoadService.acwrStatus(ratio);

    final gaugeColor = switch (status.zone) {
      TrainingZone.none => AppTheme.textMuted,
      TrainingZone.low => const Color(0xFF3B82F6),
      TrainingZone.optimal => const Color(0xFF22C55E),
      TrainingZone.high => const Color(0xFFF97316),
      TrainingZone.danger => const Color(0xFFEF4444),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glowCard(color: gaugeColor),
      child: Column(
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TRAINING LOAD',
                      style: AppTheme.mono(fontSize: 10, letterSpacing: 2, color: AppTheme.textMuted)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(status.emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(status.label,
                          style: AppTheme.heading(fontSize: 18, color: gaugeColor)),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('ACWR',
                      style: AppTheme.mono(fontSize: 9, color: AppTheme.textMuted, letterSpacing: 1)),
                  Text(ratio.toStringAsFixed(2),
                      style: AppTheme.heading(fontSize: 28, color: gaugeColor)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ACWR progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Container(color: AppTheme.surface),
                  // Optimal range indicator
                  Positioned(
                    left: 0.8 / 2.0 * MediaQuery.of(context).size.width * 0.7,
                    width: 0.5 / 2.0 * MediaQuery.of(context).size.width * 0.7,
                    top: 0, bottom: 0,
                    child: Container(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                    ),
                  ),
                  // Current position
                  FractionallySizedBox(
                    widthFactor: (ratio / 2.0).clamp(0, 1),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [gaugeColor.withValues(alpha: 0.6), gaugeColor]),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _loadStat('Acute (7d)', acute.round().toString()),
              _loadStat('Chronic (28d)', chronic.round().toString()),
              _loadStat('Ratio', ratio.toStringAsFixed(2)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _loadStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: AppTheme.heading(fontSize: 16, fontWeight: FontWeight.w700)),
        Text(label, style: AppTheme.mono(fontSize: 9, color: AppTheme.textMuted)),
      ],
    );
  }

  // ── 8.2 Weekly TRIMP Bar Chart ──
  Widget _buildTrimpChart() {
    final data = TrainingLoadService.weeklyTrimps(_workouts);
    final maxY = data.isNotEmpty ? data.reduce(math.max).ceilToDouble() + 10 : 100.0;

    return BarChart(BarChartData(
      maxY: maxY,
      barGroups: List.generate(data.length, (i) => BarChartGroupData(
        x: i,
        barRods: [BarChartRodData(
          toY: data[i],
          width: 16,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          gradient: LinearGradient(
            begin: Alignment.bottomCenter, end: Alignment.topCenter,
            colors: [AppTheme.accent.withValues(alpha: 0.4), AppTheme.accent],
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
            '${rod.toY.round()} TRIMP',
            AppTheme.mono(fontSize: 10, color: Colors.white),
          ),
        ),
      ),
    ));
  }

  // ── 8.2 Weekly Avg HR Line Chart ──
  Widget _buildAvgHrChart() {
    final data = TrainingLoadService.weeklyAvgHr(_workouts);
    final nonZero = data.where((v) => v > 0);
    if (nonZero.isEmpty) {
      return Center(child: Text('No data yet', style: AppTheme.body(color: AppTheme.textMuted)));
    }
    final minY = (nonZero.reduce(math.min) - 10).clamp(40.0, 200.0);
    final maxY = nonZero.reduce(math.max) + 10;

    return LineChart(LineChartData(
      minY: minY,
      maxY: maxY,
      lineBarsData: [LineChartBarData(
        spots: List.generate(data.length, (i) =>
            FlSpot(i.toDouble(), data[i] > 0 ? data[i] : minY)),
        isCurved: true,
        color: AppTheme.accent,
        barWidth: 2.5,
        dotData: FlDotData(show: true, getDotPainter: (s, v, bar, idx) =>
            FlDotCirclePainter(radius: 3, color: AppTheme.accent, strokeWidth: 0)),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [AppTheme.accent.withValues(alpha: 0.2), Colors.transparent],
          ),
        ),
      )],
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (v, _) => Text('W${v.toInt() + 1}',
              style: AppTheme.mono(fontSize: 8, color: AppTheme.textMuted)),
        )),
      ),
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: false),
    ));
  }

  // ── 8.5 Zone Distribution Stacked Bars ──
  Widget _buildZoneDistribution() {
    final data = TrainingLoadService.weeklyZoneDistribution(_workouts);
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

  // ── 8.2 Sessions Bar Chart ──
  Widget _buildSessionsChart() {
    final data = TrainingLoadService.weeklySessions(_workouts);
    final maxY = data.isNotEmpty ? data.reduce(math.max).toDouble() + 1 : 5.0;

    return BarChart(BarChartData(
      maxY: maxY,
      barGroups: List.generate(data.length, (i) => BarChartGroupData(
        x: i,
        barRods: [BarChartRodData(
          toY: data[i].toDouble(),
          width: 14,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          color: const Color(0xFF8B5CF6),
        )],
      )),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (v, _) => Text('W${v.toInt() + 1}',
              style: AppTheme.mono(fontSize: 8, color: AppTheme.textMuted)),
        )),
      ),
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: false),
    ));
  }
}
