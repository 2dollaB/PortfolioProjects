import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';

/// Horizontal segmented bar showing all 5 HR zones.
/// The active zone's segment glows; labels below mark the 50% → 100% HRmax scale.
class ZoneBar extends StatelessWidget {
  /// Currently active zone (1..5). Use 0 if at rest.
  final int activeZone;

  /// Whether to render the % HRmax labels under the bar.
  final bool showLabels;

  /// Bar height.
  final double height;

  const ZoneBar({
    super.key,
    required this.activeZone,
    this.showLabels = true,
    this.height = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: Row(
            children: List.generate(5, (i) {
              final z = i + 1;
              final isActive = z == activeZone;
              final color = AppColors.zoneColor(z);
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 4 ? 2 : 0),
                  decoration: BoxDecoration(
                    color: isActive
                        ? color
                        : color.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.horizontal(
                      left: i == 0 ? const Radius.circular(AppRadius.sm) : Radius.zero,
                      right: i == 4 ? const Radius.circular(AppRadius.sm) : Radius.zero,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.55),
                              blurRadius: 12,
                              spreadRadius: -2,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }),
          ),
        ),
        if (showLabels) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _Label('50%'),
              _Label('60%'),
              _Label('70%'),
              _Label('80%'),
              _Label('90%'),
              _Label('100%'),
            ],
          ),
        ],
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTheme.micro());
  }
}
