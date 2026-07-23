import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/leaderboard_repository.dart';
import '../widgets/mobile_frame.dart';

/// Studio BeatPoints leaderboard — ranks members by BeatPoints over a chosen
/// period. Visible to athletes and the trainer. Reads the denormalized
/// `studios/{id}/leaderboard` collection (athletes can't read each other's raw
/// workouts), and refreshes the viewer's own entry on open.
class LeaderboardScreen extends StatefulWidget {
  final UserProfile profile;
  const LeaderboardScreen({super.key, required this.profile});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  LbPeriod _period = LbPeriod.week;

  @override
  void initState() {
    super.initState();
    _refreshSelf();
  }

  /// Recompute and publish the signed-in athlete's own entry so their latest
  /// totals (and any pre-feature history) show up. Trainers have no entry.
  void _refreshSelf() {
    final studioId = widget.profile.studioId;
    final uid = AuthService.currentUid;
    if (studioId == null || uid == null) return;
    if (widget.profile.role != UserRole.athlete) return;
    LeaderboardRepository.recomputeSelf(
      studioId: studioId,
      uid: uid,
      name: widget.profile.name,
    ).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final studioId = widget.profile.studioId;
    return MobileFrame(
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(Strings.leaderboard, style: AppTheme.h2()),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: studioId == null
              ? _empty(Strings.lbNoStudio)
              : Column(
                  children: [
                    _periodTabs(),
                    Expanded(child: _list(studioId)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _periodTabs() {
    const items = [
      LbPeriod.week,
      LbPeriod.month,
      LbPeriod.year,
      LbPeriod.allTime,
    ];
    String label(LbPeriod p) => switch (p) {
          LbPeriod.week => Strings.lbWeek,
          LbPeriod.month => Strings.lbMonth,
          LbPeriod.year => Strings.lbYear,
          LbPeriod.allTime => Strings.lbAllTime,
        };
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          for (final p in items) ...[
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _period = p),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _period == p
                        ? AppColors.brandRed.withValues(alpha: 0.18)
                        : AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _period == p
                          ? AppColors.brandRed
                          : AppColors.border,
                    ),
                  ),
                  child: Text(
                    label(p),
                    style: AppTheme.caption(
                      color: _period == p
                          ? AppColors.brandRed
                          : AppColors.textSecondary,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _list(String studioId) {
    final now = DateTime.now();
    final myUid = AuthService.currentUid;
    return StreamBuilder<List<LeaderboardEntry>>(
      stream: LeaderboardRepository.watchStudio(studioId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.brandRed,
              strokeWidth: 2,
            ),
          );
        }
        final ranked = [...snap.data!]
          ..sort((a, b) => b.pointsFor(_period, now).compareTo(
                a.pointsFor(_period, now),
              ));
        final withPoints = ranked
            .where((e) => e.pointsFor(_period, now) > 0)
            .toList();
        if (withPoints.isEmpty) return _empty(Strings.lbEmpty);
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          itemCount: withPoints.length,
          itemBuilder: (context, i) => _row(
            rank: i + 1,
            entry: withPoints[i],
            points: withPoints[i].pointsFor(_period, now),
            isMe: withPoints[i].uid == myUid,
          ),
        );
      },
    );
  }

  Widget _row({
    required int rank,
    required LeaderboardEntry entry,
    required int points,
    required bool isMe,
  }) {
    final medal = switch (rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => null,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.brandRed.withValues(alpha: 0.10)
            : AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isMe ? AppColors.brandRed.withValues(alpha: 0.5) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: medal != null
                ? Text(medal, style: const TextStyle(fontSize: 20))
                : Text(
                    '$rank',
                    style: AppTheme.statNumber(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              entry.name.isEmpty ? Strings.athlete : entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodyLarge(
                weight: isMe ? FontWeight.w800 : FontWeight.w600,
              ).copyWith(fontSize: 15),
            ),
          ),
          if (isMe) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.brandRed.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                Strings.lbYou.toUpperCase(),
                style: AppTheme.micro(
                  color: AppColors.brandRed,
                ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 1),
              ),
            ),
          ],
          Text('⚡', style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 3),
          Text(
            '$points',
            style: AppTheme.statNumber(fontSize: 18, color: AppColors.brandRed),
          ),
        ],
      ),
    );
  }

  Widget _empty(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: AppTheme.body(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
