import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';

/// Small pill showing a zone number and color, e.g. ● Z4.
/// Use in cards, history rows, leaderboard rows.
class ZoneBadge extends StatelessWidget {
  final int zone;
  final double height;
  final bool showLabel;

  const ZoneBadge({
    super.key,
    required this.zone,
    this.height = 22,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.zoneColor(zone);
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(
        horizontal: showLabel ? AppSpacing.xs : AppSpacing.micro,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          if (showLabel) ...[
            const SizedBox(width: AppSpacing.micro + 2),
            Text(
              'Z$zone',
              style: AppTheme.micro(color: color).copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
