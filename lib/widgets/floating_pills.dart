import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/theme.dart';
import 'logo_heartbeat.dart';
import 'session_status_banner.dart';

/// A glassmorphic floating pill — used to overlay UI on top of a full-bleed
/// grid. Frosted dark background, subtle border, rounded.
class GlassPill extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final VoidCallback? onTap;

  const GlassPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.tint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = tint ?? AppColors.darkBgSecondary;
    final pill = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: (tint ?? Colors.white).withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          if (tint != null)
            BoxShadow(
              color: tint!.withValues(alpha: 0.4),
              blurRadius: 24,
              spreadRadius: -6,
            ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return pill;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: pill,
      ),
    );
  }
}

/// Top-left pill: small logo + session name. Tappable optional (e.g. for back).
class SessionTitlePill extends StatelessWidget {
  final String sessionName;
  final String? subtitle;
  final VoidCallback? onTap;
  final IconData? leadingIcon;

  const SessionTitlePill({
    super.key,
    required this.sessionName,
    this.subtitle,
    this.onTap,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPill(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leadingIcon != null)
            Icon(leadingIcon, size: 18, color: AppColors.darkTextPrimary)
          else
            const LogoHeartbeat(size: 22, showWordmark: false),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sessionName,
                style: AppTheme.bodyLarge(weight: FontWeight.w700)
                    .copyWith(fontSize: 15, height: 1.1),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: AppTheme.caption().copyWith(height: 1.1),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Top-right pill: WORK / REST / STANDBY + countdown timer.
/// Background color matches the phase — most visible identity for the session.
class PhasePill extends StatelessWidget {
  final SessionPhase phase;
  final Duration? remaining;
  final String? roundLabel;

  const PhasePill({
    super.key,
    required this.phase,
    this.remaining,
    this.roundLabel,
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
    final onColor =
        phase == SessionPhase.idle ? AppColors.darkTextPrimary : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: _color.withValues(alpha: 0.55),
            blurRadius: 24,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: onColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _label,
            style: AppTheme.h2(color: onColor).copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              fontSize: 18,
              height: 1.0,
            ),
          ),
          if (roundLabel != null) ...[
            const SizedBox(width: 8),
            Text(
              '· $roundLabel',
              style: AppTheme.caption(color: onColor.withValues(alpha: 0.85))
                  .copyWith(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          if (remaining != null) ...[
            const SizedBox(width: 12),
            Container(
              width: 1,
              height: 22,
              color: onColor.withValues(alpha: 0.35),
            ),
            const SizedBox(width: 12),
            Text(
              _formatRemaining(remaining!),
              style: AppTheme.statNumber(
                fontSize: 26,
                weight: FontWeight.w800,
                color: onColor,
              ).copyWith(height: 1.0, letterSpacing: -0.5),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bottom-right pill: compact horizontal row of group stats.
class GroupStatsPill extends StatelessWidget {
  final int avgBpm;
  final int inZ4Plus;
  final int totalAthletes;
  final String elapsed;

  const GroupStatsPill({
    super.key,
    required this.avgBpm,
    required this.inZ4Plus,
    required this.totalAthletes,
    required this.elapsed,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPill(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stat('AVG', '$avgBpm', 'bpm', AppColors.brandRed),
          _divider(),
          _stat('Z4+', '$inZ4Plus', '/$totalAthletes', AppColors.zone4),
          _divider(),
          _stat('TIME', elapsed, '', AppColors.darkTextPrimary),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, String suffix, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: AppTheme.micro().copyWith(
            letterSpacing: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: AppTheme.statNumber(fontSize: 20, color: color)
              .copyWith(height: 1.0),
        ),
        if (suffix.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(suffix, style: AppTheme.caption().copyWith(fontSize: 11)),
          ),
      ],
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 18,
        color: AppColors.darkBorder,
        margin: const EdgeInsets.symmetric(horizontal: 12),
      );
}
