import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../models/workout_summary.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/workout_repository.dart';
import '../widgets/mobile_frame.dart';
import '../widgets/zone_badge.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  String _timeFilter = 'All';
  String? _typeFilter; // null means "any type"

  static const _timeFilters = ['All', 'This week', 'This month'];
  static const _typeFilters = ['HIIT', 'Cardio', 'Strength', 'Cycling', 'Yoga'];

  /// Quick heuristic: map the mock "date" string to a day-ago count.
  /// Real implementation would compare DateTime objects from the workout.
  int _daysAgo(String date) {
    final l = date.toLowerCase();
    if (l == 'today') return 0;
    if (l == 'yesterday') return 1;
    // "Mon 19", "Sat 17" etc — assume within current month, treat as recent.
    return 10;
  }

  List<WorkoutSummary> _applyFilters(List<WorkoutSummary> all) {
    final now = DateTime.now();
    return all.where((w) {
      switch (_timeFilter) {
        case 'This week':
          if (now.difference(w.startTime).inDays > 7) return false;
          break;
        case 'This month':
          if (now.difference(w.startTime).inDays > 31) return false;
          break;
      }
      if (_typeFilter != null && w.typeLabel != _typeFilter) return false;
      return true;
    }).toList();
  }

  /// Demo fallback (prototypeMode): adapt the mock cards into the view model.
  List<WorkoutSummary> _mockSummaries() {
    final now = DateTime.now();
    return MockData.recentWorkouts.map((m) {
      final start = now.subtract(
        Duration(days: _daysAgo(m.date), minutes: m.durationMin),
      );
      return WorkoutSummary(
        id: '${m.date}-${m.type}',
        type: m.type.toLowerCase(),
        startTime: start,
        endTime: start.add(Duration(minutes: m.durationMin)),
        avgHr: m.avgBpm,
        maxHr: m.maxBpm,
        calories: m.calories,
        trimp: m.trimp,
        dominantZone: m.dominantZone,
        zoneDist: m.zoneDist,
      );
    }).toList();
  }

  Widget _buildList(List<WorkoutSummary> all) {
    final filtered = _applyFilters(all);
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            all.isEmpty
                ? 'No workouts yet.\nFinish a session and it shows up here.'
                : 'No workouts match your filters.',
            style: AppTheme.caption(),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, i) => _HistoryRow(workout: filtered[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUid;
    return MobileFrame(
      child: Scaffold(
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
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  children: [
                    for (final f in _timeFilters) ...[
                      _FilterChip(
                        label: f,
                        selected: _timeFilter == f,
                        onTap: () => setState(() => _timeFilter = f),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 10,
                      ),
                      color: AppColors.darkBorder,
                    ),
                    for (final t in _typeFilters) ...[
                      _FilterChip(
                        label: t,
                        selected: _typeFilter == t,
                        onTap: () => setState(() =>
                            _typeFilter = _typeFilter == t ? null : t),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                  ],
                ),
              ),
              const Divider(color: AppColors.darkBorder, height: 1),
              Expanded(
                child: uid == null
                    ? _buildList(_mockSummaries())
                    : StreamBuilder<List<WorkoutSummary>>(
                        stream: WorkoutRepository.watchRecent(uid),
                        builder: (context, snap) {
                          if (snap.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snap.hasError) {
                            return Center(
                              child: Text(
                                'Could not load workouts.',
                                style: AppTheme.caption(),
                              ),
                            );
                          }
                          return _buildList(snap.data ?? const []);
                        },
                      ),
              ),
            ],
          ),
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
  final WorkoutSummary workout;
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
                      workout.typeLabel,
                      style: AppTheme.bodyLarge(weight: FontWeight.w600)
                          .copyWith(fontSize: 15),
                    ),
                    Text(
                      '${workout.dateLabel} · ${workout.durationLabel}',
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
              _MiniStat(label: 'AVG', value: '${workout.avgHr}'),
              const SizedBox(width: AppSpacing.md),
              _MiniStat(label: 'MAX', value: '${workout.maxHr}'),
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
      case 'cardio':
        return Icons.directions_run_rounded;
      case 'cycling':
        return Icons.directions_bike_rounded;
      case 'yoga':
        return Icons.self_improvement_rounded;
      default:
        return Icons.favorite_rounded;
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
