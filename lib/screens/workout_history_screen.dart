import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../services/mock_data.dart';
import '../widgets/zone_badge.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  String _filter = 'All';
  final _filters = const ['All', 'This week', 'This month', 'HIIT', 'Strength'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBgPrimary,
      appBar: AppBar(
        title: const Text('History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                itemCount: _filters.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.xs),
                itemBuilder: (context, i) {
                  final f = _filters[i];
                  final selected = f == _filter;
                  return _FilterChip(
                    label: f,
                    selected: selected,
                    onTap: () => setState(() => _filter = f),
                  );
                },
              ),
            ),
            const Divider(color: AppColors.darkBorder, height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl,
                ),
                itemCount: MockData.recentWorkouts.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, i) =>
                    _HistoryRow(workout: MockData.recentWorkouts[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.xs,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.brandRed.withValues(alpha: 0.15)
                : AppColors.darkBgSecondary,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.brandRed : AppColors.darkBorder,
            ),
          ),
          child: Text(
            label,
            style: AppTheme.caption(
              color: selected
                  ? AppColors.brandRed
                  : AppColors.darkTextSecondary,
            ).copyWith(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final MockWorkout workout;
  const _HistoryRow({required this.workout});

  @override
  Widget build(BuildContext context) {
    final zoneColor = AppColors.zoneColor(workout.dominantZone);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: zoneColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(_iconFor(workout.type),
                    color: zoneColor, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workout.type,
                      style: AppTheme.bodyLarge(weight: FontWeight.w600)
                          .copyWith(fontSize: 15),
                    ),
                    Text(
                      '${workout.date} · ${workout.durationLabel}',
                      style: AppTheme.caption(),
                    ),
                  ],
                ),
              ),
              ZoneBadge(zone: workout.dominantZone, height: 22),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  for (int z = 0; z <= 5; z++)
                    if (workout.zoneDist[z] > 0)
                      Expanded(
                        flex: workout.zoneDist[z],
                        child: Container(color: AppColors.zoneColor(z)),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _MiniStat(label: 'AVG', value: '${workout.avgBpm}'),
              const SizedBox(width: AppSpacing.md),
              _MiniStat(label: 'MAX', value: '${workout.maxBpm}'),
              const SizedBox(width: AppSpacing.md),
              _MiniStat(label: 'KCAL', value: '${workout.calories}'),
              const Spacer(),
              _MiniStat(label: 'TRIMP', value: '${workout.trimp}'),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type.toLowerCase()) {
      case 'hiit':
        return Icons.bolt_rounded;
      case 'strength':
        return Icons.fitness_center_rounded;
      case 'endurance':
        return Icons.directions_run_rounded;
      case 'crossfit':
        return Icons.local_fire_department_rounded;
      default:
        return Icons.directions_run_rounded;
    }
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(label, style: AppTheme.micro().copyWith(letterSpacing: 1.2)),
        const SizedBox(width: 4),
        Text(value, style: AppTheme.statNumber(fontSize: 14)),
      ],
    );
  }
}
