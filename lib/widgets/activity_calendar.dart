import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/workout.dart';

/// 8.1 — GitHub-style activity calendar heatmap
/// Shows 26 weeks (6 months) of workout activity
class ActivityCalendar extends StatelessWidget {
  final List<Workout> workouts;
  const ActivityCalendar({super.key, required this.workouts});

  @override
  Widget build(BuildContext context) {
    // Build daily TRIMP map for last 182 days
    final today = DateTime.now();
    final dayMap = <int, double>{}; // dayIndex → total TRIMP

    for (final w in workouts) {
      final dayDiff = today.difference(w.startTime).inDays;
      if (dayDiff < 182 && dayDiff >= 0) {
        dayMap[dayDiff] = (dayMap[dayDiff] ?? 0) + w.analytics.trimp;
      }
    }

    // Find max TRIMP for normalization
    final maxTrimp = dayMap.values.isNotEmpty
        ? dayMap.values.reduce((a, b) => a > b ? a : b)
        : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grid: 7 rows (Mon–Sun) × 26 columns (weeks)
        SizedBox(
          height: 7 * 14.0 + 6 * 2.0, // 7 cells + 6 gaps
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day labels
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ['M', '', 'W', '', 'F', '', 'S']
                    .map((d) => SizedBox(
                          height: 14,
                          child: Text(d,
                              style: AppTheme.mono(
                                  fontSize: 8, color: AppTheme.textMuted)),
                        ))
                    .toList(),
              ),
              const SizedBox(width: 4),
              // Heatmap grid
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cellWidth =
                        (constraints.maxWidth - 25 * 2) / 26; // 26 weeks
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: List.generate(26, (weekIdx) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: Column(
                            children: List.generate(7, (dayIdx) {
                              final totalDays =
                                  (25 - weekIdx) * 7 + (6 - dayIdx);
                              final trimp = dayMap[totalDays] ?? 0;
                              final intensity =
                                  maxTrimp > 0 ? (trimp / maxTrimp) : 0.0;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Container(
                                  width: cellWidth.clamp(8.0, 14.0),
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: _cellColor(intensity),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Less ',
                style: AppTheme.mono(fontSize: 8, color: AppTheme.textMuted)),
            ...List.generate(5, (i) {
              return Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: _cellColor(i / 4),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
            Text(' More',
                style: AppTheme.mono(fontSize: 8, color: AppTheme.textMuted)),
          ],
        ),
      ],
    );
  }

  Color _cellColor(double intensity) {
    if (intensity <= 0) return AppTheme.surface;
    if (intensity < 0.25) return const Color(0xFF1A3D2F);
    if (intensity < 0.50) return const Color(0xFF22C55E).withValues(alpha: 0.4);
    if (intensity < 0.75) return const Color(0xFF22C55E).withValues(alpha: 0.7);
    return const Color(0xFF22C55E);
  }
}
