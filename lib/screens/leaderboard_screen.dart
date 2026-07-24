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
/// period. Athletes get a gamified header with their all-time total, tier and
/// studio rank; trainers (who don't train) just see the ranking.
class LeaderboardScreen extends StatefulWidget {
  final UserProfile profile;

  /// True when hosted as a bottom-nav tab (no back arrow, no phone frame — the
  /// shell provides both). Pushed routes leave it false.
  final bool asTab;
  const LeaderboardScreen({super.key, required this.profile, this.asTab = false});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  LbPeriod _period = LbPeriod.week;

  static const _tierFloors = [0, 500, 1500, 4000, 10000, 25000];
  static const _tierColors = [
    Color(0xFF9AA0A6), // Rookie — grey
    Color(0xFFCD7F32), // Bronze
    Color(0xFFB8C0C8), // Silver
    Color(0xFFF5C542), // Gold
    Color(0xFF6BD6D6), // Platinum
    Color(0xFFB06BFF), // Elite
  ];

  bool get _isAthlete => widget.profile.role == UserRole.athlete;

  @override
  void initState() {
    super.initState();
    _refreshSelf();
  }

  /// Publish the signed-in athlete's own entry (latest totals + back-filled
  /// history). Trainers have no entry.
  void _refreshSelf() {
    final studioId = widget.profile.studioId;
    final uid = AuthService.currentUid;
    if (studioId == null || uid == null || !_isAthlete) return;
    LeaderboardRepository.recomputeSelf(
      studioId: studioId,
      uid: uid,
      name: widget.profile.name,
    ).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final studioId = widget.profile.studioId;
    final body = SafeArea(
      child: studioId == null
          ? _empty(Strings.lbNoStudio)
          : _content(studioId),
    );
    final scaffold = Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: !widget.asTab,
        title: Text(Strings.leaderboard, style: AppTheme.h2()),
        leading: widget.asTab
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
      ),
      body: body,
    );
    // As a tab the shell already wraps everything in a MobileFrame.
    return widget.asTab ? scaffold : MobileFrame(child: scaffold);
  }

  Widget _content(String studioId) {
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
        final entries = snap.data!;
        final ranked = [...entries]..sort(
            (a, b) => b
                .pointsFor(_period, now)
                .compareTo(a.pointsFor(_period, now)),
          );
        final withPoints =
            ranked.where((e) => e.pointsFor(_period, now) > 0).toList();

        LeaderboardEntry? mine;
        for (final e in entries) {
          if (e.uid == myUid) mine = e;
        }
        final myRankIdx = withPoints.indexWhere((e) => e.uid == myUid);

        return Column(
          children: [
            if (_isAthlete)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  0,
                ),
                child: _hero(mine?.allTime ?? 0, myRankIdx),
              ),
            _periodTabs(),
            Expanded(
              child: withPoints.isEmpty
                  ? _empty(Strings.lbEmpty)
                  : ListView.builder(
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
                    ),
            ),
          ],
        );
      },
    );
  }

  // ── Gamified header: all-time total + tier progress + studio rank ──
  Widget _hero(int allTime, int myRankIdx) {
    var tier = 0;
    for (var i = 0; i < _tierFloors.length; i++) {
      if (allTime >= _tierFloors[i]) tier = i;
    }
    final color = _tierColors[tier];
    final nextAt = tier < _tierFloors.length - 1 ? _tierFloors[tier + 1] : null;
    final floor = _tierFloors[tier];
    final progress = nextAt == null
        ? 1.0
        : ((allTime - floor) / (nextAt - floor)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.22),
            AppColors.bgSecondary,
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Strings.lbYourBeatPoints.toUpperCase(),
                    style: AppTheme.micro(
                      color: AppColors.textSecondary,
                    ).copyWith(letterSpacing: 1.4),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      const Text('⚡', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 4),
                      Text(
                        '$allTime',
                        style: AppTheme.statNumber(
                          fontSize: 40,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    Strings.lbAllTimeCaps,
                    style: AppTheme.micro(color: AppColors.textSecondary),
                  ),
                ],
              ),
              const Spacer(),
              _tierBadge(tier, color, myRankIdx),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Tier progress
          Row(
            children: [
              Text(
                Strings.lbTier(tier),
                style: AppTheme.caption(
                  color: color,
                ).copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                nextAt == null
                    ? Strings.lbMaxTier
                    : Strings.lbToNext(nextAt - allTime, Strings.lbTier(tier + 1)),
                style: AppTheme.micro(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(height: 8, color: AppColors.bgTertiary),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.6), color],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tierBadge(int tier, Color color, int myRankIdx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.military_tech_rounded, size: 15, color: color),
              const SizedBox(width: 4),
              Text(
                Strings.lbTier(tier).toUpperCase(),
                style: AppTheme.micro(
                  color: color,
                ).copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.8),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          myRankIdx >= 0
              ? Strings.lbRankInStudio(myRankIdx + 1)
              : Strings.lbNotRanked,
          style: AppTheme.caption(
            color: myRankIdx >= 0
                ? AppColors.textPrimary
                : AppColors.textSecondary,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ],
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
        AppSpacing.sm,
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
          color:
              isMe ? AppColors.brandRed.withValues(alpha: 0.5) : AppColors.border,
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
          const Text('⚡', style: TextStyle(fontSize: 13)),
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
