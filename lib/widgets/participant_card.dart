import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/hr_zones.dart';
import '../config/theme.dart';
import 'heartbeat_painter.dart';

/// One athlete tile in the group-session grid.
///
/// Fully responsive — uses [LayoutBuilder] + [FittedBox] so the same widget
/// renders cleanly whether the grid is 2x1 (huge tiles) or 6x4 (tiny tiles
/// with just the BPM + zone visible).
///
/// Density tiers based on tile size:
///   - Tall (≥160dp height): full layout — avatar, name, BPM, ECG, HR% bar
///   - Mid  (110–160dp):    avatar, name, BPM, ECG (no HR% bar)
///   - Short (<110dp):      name, BPM, zone bar only — no avatar, no ECG
class ParticipantCard extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final int bpm;
  final int avgBpm;
  final int hrMax;
  final VoidCallback? onTap;

  const ParticipantCard({
    super.key,
    required this.name,
    required this.bpm,
    required this.avgBpm,
    required this.hrMax,
    this.avatarUrl,
    this.onTap,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final zone = HrZones.fromBpm(bpm, hrMax);
    final activeZone = zone == 0 ? 1 : zone;
    final color = AppColors.zoneColor(activeZone);
    final pct = hrMax > 0 ? (bpm / hrMax).clamp(0.0, 1.0) : 0.0;

    return LayoutBuilder(
      builder: (context, c) {
        final h = c.maxHeight;
        final w = c.maxWidth;
        // Density tiers
        final tall = h >= 160;
        final mid = h >= 110 && !tall;
        final showEcg = h >= 110 && w >= 140;
        final showAvatar = w >= 140;
        final compactPad = h < 110 ? 6.0 : 8.0;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.darkBgSecondary,
                borderRadius: BorderRadius.circular(12),
                // Zone color tints the border, so identity is readable even at distance
                border: Border.all(color: color.withValues(alpha: 0.45), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.10),
                    blurRadius: 12,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    // Left edge color stripe
                    Container(width: 3, color: color),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(compactPad),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Top row: avatar (if room) + name + zone badge ──
                            _TopRow(
                              initials: _initials,
                              name: name,
                              zone: activeZone,
                              color: color,
                              showAvatar: showAvatar,
                              dense: !tall,
                            ),
                            const SizedBox(height: 2),
                            // ── BPM ──
                            Expanded(
                              child: _BpmBlock(
                                bpm: bpm,
                                color: color,
                                showUnit: tall || mid,
                              ),
                            ),
                            // ── Bottom row: ECG (if room) ──
                            if (showEcg) ...[
                              SizedBox(
                                height: tall ? 24 : 18,
                                child: ScrollingEcg(
                                  bpm: bpm,
                                  color: color,
                                  strokeWidth: 1.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            // ── HR% bar — always shown, takes 4dp ──
                            _HrPctBar(pct: pct, color: color),
                            if (tall) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'avg ${avgBpm > 0 ? avgBpm : "--"}',
                                    style: AppTheme.micro(),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${(pct * 100).round()}%',
                                    style: AppTheme.micro(color: color)
                                        .copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Avatar + name + zone badge — collapses gracefully when space is tight.
class _TopRow extends StatelessWidget {
  final String initials;
  final String name;
  final int zone;
  final Color color;
  final bool showAvatar;
  final bool dense;

  const _TopRow({
    required this.initials,
    required this.name,
    required this.zone,
    required this.color,
    required this.showAvatar,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: dense ? 30 : 36,
      child: Row(
        children: [
          if (showAvatar) ...[
            Container(
              width: dense ? 24 : 30,
              height: dense ? 24 : 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.2),
                border: Border.all(
                  color: color.withValues(alpha: 0.45),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: AppTheme.caption(color: color).copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: dense ? 11 : 13,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.bodyLarge(weight: FontWeight.w700).copyWith(
                  fontSize: dense ? 17 : 20,
                  height: 1.1,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Solid zone-color chip with big Z number — most visible identity element
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 8 : 10,
              vertical: dense ? 3 : 4,
            ),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 8,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Text(
              'Z$zone',
              style: TextStyle(
                fontSize: dense ? 16 : 19,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.0,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// BPM number + "bpm" unit — auto-scales to fill the available block.
class _BpmBlock extends StatelessWidget {
  final int bpm;
  final Color color;
  final bool showUnit;

  const _BpmBlock({
    required this.bpm,
    required this.color,
    required this.showUnit,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$bpm',
              style: AppTheme.statNumber(
                fontSize: 56,
                weight: FontWeight.w800,
                color: color,
              ).copyWith(height: 1.0, letterSpacing: -1),
            ),
            if (showUnit) ...[
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'bpm',
                  style: AppTheme.caption(color: AppColors.darkTextSecondary)
                      .copyWith(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HrPctBar extends StatelessWidget {
  final double pct;
  final Color color;
  const _HrPctBar({required this.pct, required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.darkBgTertiary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        FractionallySizedBox(
          widthFactor: pct,
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: -1,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
