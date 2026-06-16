import 'dart:math' as math;
import '../widgets/mobile_frame.dart';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../services/session_store.dart';
import '../widgets/beat_button.dart';
import '../widgets/stat_chip.dart';
import '../widgets/workout_type_sheet.dart';
import '../widgets/zone_badge.dart';

/// Detailed analytics for a single completed session.
///
/// Layout:
///   Header: type icon + session name + date + duration
///   Hero stats: avg group BPM + group TRIMP
///   Time-in-zones donut
///   Athletes list â€” per-athlete name, BPM, TRIMP, dominant zone
class SessionDetailScreen extends StatelessWidget {
  final SessionRecord record;

  const SessionDetailScreen({super.key, required this.record});

  String _formatDate(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} · $h:$m';
  }

  /// Average time-in-zones across athletes.
  List<int> _avgZones() {
    final out = List<int>.filled(6, 0);
    if (record.results.isEmpty) return out;
    for (final r in record.results) {
      for (int z = 0; z < 6; z++) {
        out[z] += r.timeInZones[z];
      }
    }
    return out.map((v) => v ~/ record.results.length).toList();
  }

  @override
  Widget build(BuildContext context) {
    final zones = _avgZones();
    final hottestZone = zones.indexOf(zones.reduce(math.max));
    return MobileFrame(
      child: Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Session analytics'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl,
          ),
          children: [
            _Header(record: record, formatted: _formatDate(record.startedAt)),
            const SizedBox(height: AppSpacing.lg),
            _HeroStats(record: record),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(child: StatChip(label: 'Athletes', value: '${record.athleteCount}')),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: StatChip(label: 'Duration', value: record.durationLabel)),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: StatChip(
                  label: 'Dominant',
                  value: 'Z$hottestZone',
                  accent: AppColors.zoneColor(hottestZone == 0 ? 1 : hottestZone),
                )),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Time in zones', style: AppTheme.h2()),
            Text('Group average across all athletes',
                style: AppTheme.caption()),
            const SizedBox(height: AppSpacing.sm),
            _ZoneBar(zones: zones),
            const SizedBox(height: AppSpacing.md),
            for (int z = 1; z <= 5; z++) ...[
              _ZoneRow(
                zone: z,
                percent: zones[z],
                minutes: record.durationMin * zones[z] ~/ 100,
              ),
              if (z < 5) const SizedBox(height: 6),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text('Athletes', style: AppTheme.h2()),
            Text('${record.results.length} participated',
                style: AppTheme.caption()),
            const SizedBox(height: AppSpacing.sm),
            for (final r in record.results) ...[
              _AthleteRow(result: r, hrMaxRef: 200),
              const SizedBox(height: AppSpacing.xs),
            ],
            const SizedBox(height: AppSpacing.lg),
            // Finalize action — returns all the way to the home screen.
            BeatPrimaryButton(
              label: 'Back to home',
              icon: Icons.home_rounded,
              onPressed: () =>
                  Navigator.of(context).popUntil((r) => r.isFirst),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final SessionRecord record;
  final String formatted;
  const _Header({required this.record, required this.formatted});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.brandRed.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(record.type.icon, color: AppColors.brandRed, size: 26),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(record.name, style: AppTheme.h2()),
              Text(
                '${record.type.displayName} · $formatted',
                style: AppTheme.caption(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroStats extends StatelessWidget {
  final SessionRecord record;
  const _HeroStats({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text('AVG GROUP HR',
                    style: AppTheme.micro().copyWith(letterSpacing: 1.4)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${record.avgGroupBpm}',
                  style: AppTheme.statNumber(
                    fontSize: 44,
                    color: AppColors.brandRed,
                  ),
                ),
                Text('bpm', style: AppTheme.caption()),
              ],
            ),
          ),
          Container(width: 1, height: 72, color: AppColors.border),
          Expanded(
            child: Column(
              children: [
                Text('GROUP TRIMP',
                    style: AppTheme.micro().copyWith(letterSpacing: 1.4)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${record.groupTrimp}',
                  style: AppTheme.statNumber(
                    fontSize: 44,
                    color: AppColors.warning,
                  ),
                ),
                Text('avg per athlete', style: AppTheme.caption()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ZoneBar extends StatelessWidget {
  final List<int> zones;
  const _ZoneBar({required this.zones});

  @override
  Widget build(BuildContext context) {
    final total = zones.fold<int>(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 16,
        child: Row(
          children: [
            for (int z = 0; z <= 5; z++)
              if (zones[z] > 0)
                Expanded(
                  flex: zones[z],
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
  final int minutes;
  const _ZoneRow({
    required this.zone,
    required this.percent,
    required this.minutes,
  });

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
        Text('Z$zone',
            style: AppTheme.caption(color: c)
                .copyWith(fontWeight: FontWeight.w600)),
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
          width: 56,
          child: Text(
            '$percent% · ${minutes}m',
            style: AppTheme.caption(),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _AthleteRow extends StatelessWidget {
  final AthleteResult result;
  final int hrMaxRef;
  const _AthleteRow({required this.result, required this.hrMaxRef});

  String get _initials {
    final parts = result.name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final zoneColor = AppColors.zoneColor(result.dominantZone);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: zoneColor.withValues(alpha: 0.18),
              border: Border.all(color: zoneColor.withValues(alpha: 0.4)),
            ),
            alignment: Alignment.center,
            child: Text(
              _initials,
              style: AppTheme.caption(color: zoneColor)
                  .copyWith(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.name,
                  style: AppTheme.bodyLarge(weight: FontWeight.w600)
                      .copyWith(fontSize: 14),
                ),
                Text(
                  'avg ${result.avgBpm} · peak ${result.maxBpm}',
                  style: AppTheme.caption(),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${result.trimp}',
                      style: AppTheme.statNumber(fontSize: 16)),
                  const SizedBox(width: 3),
                  Text('TRIMP', style: AppTheme.micro()),
                ],
              ),
              const SizedBox(height: 2),
              ZoneBadge(zone: result.dominantZone, height: 18),
            ],
          ),
        ],
      ),
    );
  }
}
