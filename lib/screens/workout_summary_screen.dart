import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../models/user_profile.dart';
import '../widgets/beat_button.dart';
import '../widgets/calc_info_button.dart';
import '../widgets/mobile_frame.dart';
import '../widgets/stat_chip.dart';
import '../widgets/workout_type_sheet.dart';
import '../widgets/zone_badge.dart';

/// Post-workout summary. Hero stats + zone distribution + grid of metrics.
class WorkoutSummaryScreen extends StatelessWidget {
  final UserProfile profile;
  final int durationMin;
  final int avgBpm;
  final int maxBpm;
  final int calories;
  final int trimp;
  final WorkoutType? workoutType;

  /// Real per-zone percentages (index 0-5) from the finished workout.
  /// Null keeps the demo constants (prototype path).
  final List<int>? zoneDist;

  const WorkoutSummaryScreen({
    super.key,
    required this.profile,
    required this.durationMin,
    required this.avgBpm,
    required this.maxBpm,
    required this.calories,
    required this.trimp,
    this.workoutType,
    this.zoneDist,
  });

  String _formatDuration() {
    final h = durationMin ~/ 60;
    final m = durationMin % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  List<int> get _zoneDist => zoneDist ?? const [0, 6, 18, 38, 30, 8];

  int get _dominantZone {
    int best = 1;
    int max = 0;
    for (int z = 1; z < _zoneDist.length; z++) {
      if (_zoneDist[z] > max) {
        max = _zoneDist[z];
        best = z;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text(Strings.workoutSummary),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl,
          ),
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.brandRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    workoutType?.icon ?? Icons.local_fire_department_rounded,
                    color: AppColors.brandRed,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          workoutType != null
                              ? Strings.workoutTypeLabel(workoutType!.displayName)
                              : Strings.workoutFallback,
                          style: AppTheme.h2().copyWith(fontSize: 18)),
                      Text(
                        '${DateTime.now().toString().substring(0, 16)} · ${_formatDuration()}',
                        style: AppTheme.caption(),
                      ),
                    ],
                  ),
                ),
                ZoneBadge(zone: _dominantZone),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Hero stats
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          Strings.average,
                          style: AppTheme.micro().copyWith(letterSpacing: 1.4),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '$avgBpm',
                          style: AppTheme.statNumber(
                            fontSize: 48,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text('bpm', style: AppTheme.caption()),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 72,
                    color: AppColors.border,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          Strings.peak,
                          style: AppTheme.micro().copyWith(letterSpacing: 1.4),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '$maxBpm',
                          style: AppTheme.statNumber(
                            fontSize: 48,
                            color: AppColors.brandRed,
                          ),
                        ),
                        Text('bpm', style: AppTheme.caption()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            Row(
              children: [
                Text(Strings.timeInZones, style: AppTheme.h2()),
                const SizedBox(width: 4),
                CalcInfoButton(
                  title: Strings.zonesInfoTitle,
                  body: Strings.zonesInfoBody,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _ZoneDistributionBar(distribution: _zoneDist),
            const SizedBox(height: AppSpacing.md),
            for (int z = 1; z <= 5; z++) ...[
              _ZoneRow(
                zone: z,
                percent: _zoneDist[z],
                seconds: durationMin * 60 * _zoneDist[z] ~/ 100,
              ),
              if (z < 5) const SizedBox(height: 6),
            ],

            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Text(Strings.details, style: AppTheme.h2()),
                const SizedBox(width: 4),
                CalcInfoButton(
                  title: Strings.calcInfoTitle,
                  body: Strings.calcInfoBody,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: AppSpacing.xs,
              crossAxisSpacing: AppSpacing.xs,
              childAspectRatio: 1.3,
              children: [
                StatChip(
                  label: Strings.calories,
                  value: '$calories',
                  unit: 'kcal',
                  icon: Icons.local_fire_department_rounded,
                  accent: AppColors.brandRed,
                ),
                StatChip(
                  label: 'TRIMP',
                  value: '$trimp',
                  icon: Icons.bolt_rounded,
                  accent: AppColors.warning,
                ),
                StatChip(
                  label: Strings.duration,
                  value: _formatDuration(),
                  icon: Icons.timer_outlined,
                ),
                StatChip(
                  label: Strings.avgHr,
                  value: '$avgBpm',
                  unit: 'bpm',
                  icon: Icons.favorite_outline_rounded,
                ),
                StatChip(
                  label: Strings.maxHr,
                  value: '$maxBpm',
                  unit: 'bpm',
                  icon: Icons.trending_up_rounded,
                  accent: AppColors.brandRed,
                ),
                StatChip(
                  label: Strings.hrMaxPct,
                  value: '${(maxBpm / profile.hrMax * 100).round()}',
                  unit: '%',
                  icon: Icons.percent_rounded,
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),
            BeatPrimaryButton(
              label: Strings.saveWorkout,
              icon: Icons.check_rounded,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: AppSpacing.sm),
            BeatSecondaryButton(
              label: Strings.discard,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _ZoneDistributionBar extends StatelessWidget {
  final List<int> distribution;
  const _ZoneDistributionBar({required this.distribution});

  @override
  Widget build(BuildContext context) {
    final total = distribution.fold<int>(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: SizedBox(
        height: 14,
        child: Row(
          children: [
            for (int z = 0; z <= 5; z++)
              if (distribution[z] > 0)
                Expanded(
                  flex: distribution[z],
                  child: Container(color: AppColors.zoneColor(z)),
                ),
          ],
        ),
      ),
    );
  }
}

class _ZoneRow extends StatelessWidget {
  final int zone;
  final int percent;
  final int seconds;
  const _ZoneRow({
    required this.zone,
    required this.percent,
    required this.seconds,
  });

  /// "45s" under a minute, "12m" above — short workouts otherwise read
  /// "0m" for every zone (E2E-6).
  String get _timeLabel =>
      seconds < 60 ? '${seconds}s' : '${seconds ~/ 60}m';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.zoneColor(zone);
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text('Z$zone', style: AppTheme.caption(color: c).copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.bgTertiary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (percent / 100).clamp(0.0, 1.0),
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 68,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '$percent% · $_timeLabel',
              style: AppTheme.caption(),
              maxLines: 1,
            ),
          ),
        ),
      ],
    );
  }
}
