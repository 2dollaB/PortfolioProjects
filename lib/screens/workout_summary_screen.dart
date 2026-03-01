import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../config/hr_zones.dart';
import '../config/theme.dart';
import '../models/workout.dart';

class WorkoutSummaryScreen extends StatelessWidget {
  final Workout workout;

  const WorkoutSummaryScreen({super.key, required this.workout});

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final a = workout.analytics;
    final duration = workout.duration;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.accent.withValues(alpha: 0.1),
              AppTheme.background,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // ── Header ──
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accent.withValues(alpha: 0.15),
                  ),
                  child: const Icon(Icons.emoji_events_rounded,
                      size: 48, color: Color(0xFFFFD700)),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Workout Complete!',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatDuration(duration),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w200,
                    color: AppTheme.accentLight,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Key Metrics Grid ──
                Row(
                  children: [
                    Expanded(child: _buildMetricCard(
                      'Avg HR', '${a.avgHr}', 'bpm',
                      Icons.favorite_outline, AppTheme.accent,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _buildMetricCard(
                      'Max HR', '${a.maxHr}', 'bpm',
                      Icons.arrow_upward_rounded, HrZones.colors[5]!,
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildMetricCard(
                      'Calories', '${a.calories.round()}', 'kcal',
                      Icons.local_fire_department, const Color(0xFFF97316),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _buildMetricCard(
                      'TRIMP', a.trimp.toStringAsFixed(1), 'load',
                      Icons.timeline_rounded, const Color(0xFF8B5CF6),
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildMetricCard(
                      'Training Effect', a.trainingEffect.toStringAsFixed(1),
                      a.trainingEffectLabel,
                      Icons.trending_up_rounded, const Color(0xFF06B6D4),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _buildMetricCard(
                      'HR Recovery', '${a.hrRecovery > 0 ? "-" : ""}${a.hrRecovery}',
                      'bpm/60s',
                      Icons.arrow_downward_rounded, const Color(0xFF22C55E),
                    )),
                  ],
                ),

                const SizedBox(height: 32),

                // ── HR Timeline Graph ──
                _buildSectionTitle('Heart Rate Timeline'),
                const SizedBox(height: 12),
                Container(
                  height: 200,
                  padding: const EdgeInsets.fromLTRB(0, 16, 16, 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _buildHrTimeline(),
                ),

                const SizedBox(height: 32),

                // ── Zone Distribution ──
                _buildSectionTitle('Zone Distribution'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 160,
                        child: _buildZonePieChart(duration),
                      ),
                      const SizedBox(height: 16),
                      ...List.generate(5, (index) {
                        final zone = index + 1;
                        return _buildZoneRow(zone, duration);
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Done Button ──
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Done',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: color)),
          Text(unit,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildHrTimeline() {
    if (workout.dataPoints.isEmpty) {
      return const Center(child: Text('No data'));
    }

    // Downsample for performance
    final points = _downsample(workout.dataPoints, 150);
    final startTime = workout.startTime;

    final spots = points.map((dp) {
      final seconds = dp.timestamp.difference(startTime).inSeconds.toDouble();
      return FlSpot(seconds, dp.bpm.toDouble());
    }).toList();

    if (spots.length < 2) return const Center(child: Text('Not enough data'));

    final maxSeconds = workout.duration.inSeconds.toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: AppTheme.surfaceLight, strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              interval: 20,
              getTitlesWidget: (value, _) => Text(
                '${value.toInt()}',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
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
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 10));
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
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            gradient: LinearGradient(
              colors: [
                HrZones.colors[2]!,
                HrZones.colors[3]!,
                HrZones.colors[4]!,
                HrZones.colors[5]!,
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
                  AppTheme.accent.withValues(alpha: 0.2),
                  AppTheme.accent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          // Avg HR line
          LineChartBarData(
            spots: [
              FlSpot(0, workout.analytics.avgHr.toDouble()),
              FlSpot(maxSeconds, workout.analytics.avgHr.toDouble()),
            ],
            isCurved: false,
            color: AppTheme.accent.withValues(alpha: 0.5),
            barWidth: 1,
            dashArray: [5, 5],
            dotData: const FlDotData(show: false),
          ),
        ],
        minY: 40,
        maxY: (workout.analytics.hrMax + 10).toDouble(),
        lineTouchData: const LineTouchData(enabled: false),
      ),
    );
  }

  Widget _buildZonePieChart(Duration totalDuration) {
    final percentages = workout.analytics.zonePercentages(totalDuration);

    final sections = <PieChartSectionData>[];
    for (int zone = 1; zone <= 5; zone++) {
      final pct = percentages[zone] ?? 0;
      if (pct > 0) {
        sections.add(PieChartSectionData(
          value: pct,
          color: HrZones.colors[zone]!,
          radius: 35,
          showTitle: pct > 8,
          title: '${pct.round()}%',
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ));
      }
    }

    if (sections.isEmpty) {
      return const Center(child: Text('No zone data'));
    }

    return PieChart(PieChartData(
      sections: sections,
      centerSpaceRadius: 40,
      sectionsSpace: 2,
    ));
  }

  Widget _buildZoneRow(int zone, Duration totalDuration) {
    final color = HrZones.colors[zone]!;
    final name = HrZones.names[zone] ?? '';
    final timeInZone = workout.analytics.timeInZone[zone] ?? Duration.zero;
    final pct = totalDuration.inSeconds > 0
        ? (timeInZone.inSeconds / totalDuration.inSeconds * 100)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 24,
            child: Text('Z$zone',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(name,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ),
          Text(_formatDuration(timeInZone),
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(width: 8),
          SizedBox(
            width: 45,
            child: Text('${pct.round()}%',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ),
        ],
      ),
    );
  }

  /// Downsample data points for chart rendering
  List<HrDataPoint> _downsample(List<HrDataPoint> data, int maxPoints) {
    if (data.length <= maxPoints) return data;
    final step = data.length / maxPoints;
    return List.generate(maxPoints, (i) => data[(i * step).floor()]);
  }
}
