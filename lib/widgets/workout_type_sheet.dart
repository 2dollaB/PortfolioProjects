import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';

/// Workout type — picked before starting a solo workout.
/// Saved with the workout so history can filter/group by type.
enum WorkoutType {
  hiit,
  strength,
  endurance,
  cardio,
  crossfit,
}

extension WorkoutTypeMeta on WorkoutType {
  String get displayName {
    switch (this) {
      case WorkoutType.hiit:
        return 'HIIT';
      case WorkoutType.strength:
        return 'Strength';
      case WorkoutType.endurance:
        return 'Endurance';
      case WorkoutType.cardio:
        return 'Cardio';
      case WorkoutType.crossfit:
        return 'CrossFit';
    }
  }

  String get description {
    switch (this) {
      case WorkoutType.hiit:
        return 'High-intensity intervals';
      case WorkoutType.strength:
        return 'Weights · resistance';
      case WorkoutType.endurance:
        return 'Long, steady effort';
      case WorkoutType.cardio:
        return 'Sustained moderate pace';
      case WorkoutType.crossfit:
        return 'Functional · circuits';
    }
  }

  IconData get icon {
    switch (this) {
      case WorkoutType.hiit:
        return Icons.bolt_rounded;
      case WorkoutType.strength:
        return Icons.fitness_center_rounded;
      case WorkoutType.endurance:
        return Icons.directions_run_rounded;
      case WorkoutType.cardio:
        return Icons.favorite_rounded;
      case WorkoutType.crossfit:
        return Icons.local_fire_department_rounded;
    }
  }
}

/// Bottom sheet: pick a workout type. Returns the [WorkoutType] or null
/// if dismissed.
class WorkoutTypeSheet {
  WorkoutTypeSheet._();

  static Future<WorkoutType?> show(BuildContext context) {
    return showModalBottomSheet<WorkoutType>(
      context: context,
      backgroundColor: AppColors.bgSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _WorkoutTypeSheetContent(),
    );
  }
}

class _WorkoutTypeSheetContent extends StatelessWidget {
  const _WorkoutTypeSheetContent();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pull handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.bgTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(Strings.whatTraining, style: AppTheme.h2()),
            const SizedBox(height: AppSpacing.xs),
            Text(
              Strings.tagSessionHint,
              style: AppTheme.caption(),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final t in WorkoutType.values) ...[
              _TypeOption(
                type: t,
                onTap: () => Navigator.of(context).pop(t),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  final WorkoutType type;
  final VoidCallback onTap;
  const _TypeOption({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.bgPrimary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.brandRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(type.icon, color: AppColors.brandRed, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Strings.workoutTypeLabel(type.displayName),
                      style: AppTheme.bodyLarge(weight: FontWeight.w600)
                          .copyWith(fontSize: 15),
                    ),
                    Text(Strings.workoutTypeDesc(type.displayName),
                        style: AppTheme.caption()),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
