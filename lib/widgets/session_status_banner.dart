import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';

enum SessionPhase { work, rest, idle }

/// Full-width banner across the top of a group session.
/// Shows the current interval phase + countdown to the next change.
class SessionStatusBanner extends StatelessWidget {
  final SessionPhase phase;

  /// Time remaining in the current phase. Pass null to hide the timer.
  final Duration? remaining;

  /// Optional round count like "Round 3/8".
  final String? subtitle;

  const SessionStatusBanner({
    super.key,
    required this.phase,
    this.remaining,
    this.subtitle,
  });

  Color get _color {
    switch (phase) {
      case SessionPhase.work:
        return AppColors.brandRed;
      case SessionPhase.rest:
        return AppColors.success;
      case SessionPhase.idle:
        return AppColors.darkBgTertiary;
    }
  }

  String get _label {
    switch (phase) {
      case SessionPhase.work:
        return 'WORK';
      case SessionPhase.rest:
        return 'REST';
      case SessionPhase.idle:
        return 'STANDBY';
    }
  }

  String _formatRemaining(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m > 0) return '$m:${s.toString().padLeft(2, '0')}';
    return ':${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final onColor = phase == SessionPhase.idle
        ? AppColors.darkTextPrimary
        : Colors.white;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: phase == SessionPhase.idle
            ? null
            : [
                BoxShadow(
                  color: _color.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: -4,
                ),
              ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _label,
                style: AppTheme.h2(color: onColor).copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  fontSize: 16,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: AppTheme.caption(
                    color: onColor.withValues(alpha: 0.75),
                  ),
                ),
            ],
          ),
          const Spacer(),
          if (remaining != null)
            Text(
              _formatRemaining(remaining!),
              style: AppTheme.statNumber(
                fontSize: 36,
                weight: FontWeight.w700,
                color: onColor,
              ),
            ),
        ],
      ),
    );
  }
}
