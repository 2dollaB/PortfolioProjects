import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';

/// Small stat container: label on top (caption), value below (display number).
/// Used in rows of 3-4 on workout summary and dashboards.
class StatChip extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData? icon;
  final Color? accent;

  const StatChip({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.icon,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.brandRed;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: color),
                const SizedBox(width: AppSpacing.micro),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: AppTheme.micro().copyWith(letterSpacing: 1.2),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.micro),
          // FittedBox + scaleDown so a long unit ("this week") never overflows.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: AppTheme.statNumber(fontSize: 22)),
                if (unit != null) ...[
                  const SizedBox(width: 3),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(unit!, style: AppTheme.caption()),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
