import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../models/cloud_session.dart';
import '../models/user_profile.dart';
import '../models/workout_summary.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/session_repository.dart';
import '../services/workout_repository.dart';
import '../widgets/beat_button.dart';
import '../widgets/home_header.dart';
import '../widgets/mobile_frame.dart';
import '../widgets/stat_chip.dart';
import '../widgets/zone_badge.dart';
import 'workout_history_screen.dart';
import 'workout_summary_screen.dart';
import 'solo_setup_screen.dart';
import 'join_session_screen.dart';
import 'join_studio_screen.dart';
import 'session_lobby_screen.dart';
import 'settings_screen.dart';

/// Athlete home — greeting, hero "Start Workout" card, recent workouts strip,
/// weekly stats. Designed as the first impression of the app.
class HomeScreen extends StatelessWidget {
  final UserProfile profile;
  // ignore: unused_element_parameter
  final void Function(UserProfile)? onProfileUpdated;
  final VoidCallback? onSignOut;

  /// Production-only: when true and the athlete isn't in a studio yet, show the
  /// "Join a studio" CTA. Left false in the prototype/demo so home is unchanged.
  final bool enableStudioJoin;

  const HomeScreen({
    super.key,
    required this.profile,
    this.onProfileUpdated,
    this.onSignOut,
    this.enableStudioJoin = false,
  });

  String _firstName() {
    final n = profile.name.trim();
    if (n.isEmpty) return Strings.athlete;
    return n.split(RegExp(r'\s+')).first;
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return Strings.goodMorning;
    if (h < 18) return Strings.goodAfternoon;
    return Strings.goodEvening;
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUid;
    if (uid == null) return _buildHome(context, MockData.recentSummaries());
    return StreamBuilder<List<WorkoutSummary>>(
      stream: WorkoutRepository.watchRecent(uid),
      builder: (context, snap) => _buildHome(context, snap.data),
    );
  }

  /// [workouts] is null while the production stream is still loading.
  Widget _buildHome(BuildContext context, List<WorkoutSummary>? workouts) {
    return MobileFrame(
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.xl,
                    AppSpacing.xl,
                  ),
                  child: HomeHeader(
                    greeting: _greeting(),
                    name: _firstName(),
                    initials: HomeHeader.initialsOf(profile.name),
                    onAvatarTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SettingsScreen(
                          profile: profile,
                          onSignOut: onSignOut,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // PRIMARY — group training is the app's main use case, so this is
              // the big hero card: "Join a studio" until the athlete belongs to
              // one, then the reactive "Available workout" card once they do.
              // Mutually exclusive, so home shows exactly one primary card.
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                sliver: SliverToBoxAdapter(
                  child: enableStudioJoin && profile.studioId == null
                      ? const _JoinStudioHero()
                      : _AvailableWorkoutHero(profile: profile),
                ),
              ),

              // SECONDARY — solo workout, demoted below the group CTA.
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  AppSpacing.xl,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _JoinCard(
                    icon: Icons.directions_run_rounded,
                    title: Strings.startWorkout,
                    subtitle: Strings.startWorkoutSubtitle,
                    // Setup step first (strap + optional intervals); the
                    // workout only starts when they press Start there.
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SoloSetupScreen(profile: profile),
                      ),
                    ),
                  ),
                ),
              ),

              // STATS THIS WEEK
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xs,
                ),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(Strings.thisWeek),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                sliver: SliverToBoxAdapter(
                  child: _WeeklyStats(workouts: workouts),
                ),
              ),

              // RECENT WORKOUTS
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  AppSpacing.xs,
                ),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(
                    Strings.recentWorkouts,
                    trailing: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              WorkoutHistoryScreen(profile: profile),
                        ),
                      ),
                      child: Text(Strings.seeAll),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                sliver: SliverToBoxAdapter(
                  child: _RecentList(
                    workouts: workouts?.take(3).toList(),
                    profile: profile,
                  ),
                ),
              ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader(this.title, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppTheme.h2()),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

/// Shared gradient/glow container for the home screen's primary CTA — used by
/// both the "Join a studio" and "Available workout" hero cards so the
/// prominent group-training slot always reads the same way.
class _PrimaryCard extends StatelessWidget {
  final Widget child;
  const _PrimaryCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        // Semantic surfaces, not the old hardcoded dark pair — in light mode
        // the heading rendered dark-on-dark (E2E-8).
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.bgTertiary, AppColors.bgSecondary],
        ),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandRed.withValues(alpha: 0.12),
            blurRadius: 32,
            spreadRadius: -8,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Primary hero CTA shown until the athlete belongs to a studio.
class _JoinStudioHero extends StatelessWidget {
  const _JoinStudioHero();

  @override
  Widget build(BuildContext context) {
    return _PrimaryCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.brandRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.group_add_rounded,
                  color: AppColors.brandRed,
                  size: 16,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  Strings.joinGroupSession.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.micro(
                    color: AppColors.brandRed,
                  ).copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            Strings.joinAStudio,
            style: AppTheme.h1().copyWith(fontSize: 32, height: 1.1),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            Strings.joinStudioHint,
            style: AppTheme.bodyLarge(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          BeatPrimaryButton(
            label: Strings.joinStudioBtn,
            icon: Icons.arrow_forward_rounded,
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const JoinStudioScreen())),
          ),
        ],
      ),
    );
  }
}

/// Primary hero CTA once the athlete is in a studio — reactively shows the
/// trainer's live session, or a placeholder when nothing is running.
class _AvailableWorkoutHero extends StatelessWidget {
  final UserProfile profile;
  const _AvailableWorkoutHero({required this.profile});

  @override
  Widget build(BuildContext context) {
    final studioId = profile.studioId;
    if (AuthService.currentUid == null || studioId == null) {
      // Prototype/demo — no cloud studio to watch, keep the static walk-through CTA.
      return _PrimaryCard(child: _content(context, live: null));
    }
    return StreamBuilder<CloudSession?>(
      stream: SessionRepository.watchLive(studioId),
      builder: (context, snap) =>
          _PrimaryCard(child: _content(context, live: snap.data)),
    );
  }

  Widget _content(BuildContext context, {required CloudSession? live}) {
    if (live != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.brandRed,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                Strings.liveNow,
                style: AppTheme.micro(
                  color: AppColors.brandRed,
                ).copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            live.name,
            style: AppTheme.h1().copyWith(fontSize: 32, height: 1.1),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            Strings.groupWorkout,
            style: AppTheme.bodyLarge(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          BeatPrimaryButton(
            label: Strings.joinSession,
            icon: Icons.play_arrow_rounded,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    SessionLobbyScreen(profile: profile, session: live),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.textTertiary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                Icons.event_busy_rounded,
                color: AppColors.textSecondary,
                size: 16,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                Strings.joinGroupSession.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.micro(
                  color: AppColors.textSecondary,
                ).copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          Strings.noLiveSession,
          style: AppTheme.h1().copyWith(fontSize: 26, height: 1.1),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          Strings.noLiveSessionHint,
          style: AppTheme.bodyLarge(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        BeatSecondaryButton(
          label: Strings.scanToJoin,
          icon: Icons.qr_code_scanner_rounded,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => JoinSessionScreen(profile: profile),
            ),
          ),
        ),
      ],
    );
  }
}

class _WeeklyStats extends StatelessWidget {
  /// Null while the production stream is still loading.
  final List<WorkoutSummary>? workouts;
  const _WeeklyStats({required this.workouts});

  @override
  Widget build(BuildContext context) {
    final all = workouts;
    var sessions = '–', time = '–', beatPoints = '–';
    if (all != null) {
      final now = DateTime.now();
      // Same rolling-7-day window as the history screen's "This week" filter.
      final week = all
          .where((w) => now.difference(w.startTime).inDays <= 7)
          .toList();
      final minutes = week.fold(0, (sum, w) => sum + w.durationMin);
      final h = minutes ~/ 60;
      final m = minutes % 60;
      sessions = '${week.length}';
      time = h > 0 ? '${h}h ${m}m' : '${m}m';
      beatPoints = '${week.fold(0, (sum, w) => sum + w.beatPoints)}';
    }
    return Row(
      children: [
        // No "this week" unit — the section header already says the period,
        // so "1 ovaj tjedan" read like a typo next to the plain chips.
        Expanded(
          child: StatChip(label: Strings.sessions, value: sessions),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: StatChip(label: Strings.time, value: time),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: StatChip(label: Strings.beatPoints, value: beatPoints),
        ),
      ],
    );
  }
}

class _RecentList extends StatelessWidget {
  /// Null while the production stream is still loading.
  final List<WorkoutSummary>? workouts;
  final UserProfile profile;
  const _RecentList({required this.workouts, required this.profile});

  @override
  Widget build(BuildContext context) {
    final all = workouts;
    if (all == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (all.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text(
            Strings.noWorkoutsYet,
            style: AppTheme.caption(),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final w in all) ...[
          _WorkoutRow(workout: w, profile: profile),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _WorkoutRow extends StatelessWidget {
  final WorkoutSummary workout;
  final UserProfile profile;
  const _WorkoutRow({required this.workout, required this.profile});

  bool get _isGroup => workout.type.toLowerCase() == 'group';

  @override
  Widget build(BuildContext context) {
    final zoneColor = AppColors.zoneColor(workout.dominantZone);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WorkoutSummaryScreen(
              profile: profile,
              durationMin: workout.durationMin,
              avgBpm: workout.avgHr,
              maxBpm: workout.maxHr,
              calories: workout.calories,
              beatPoints: workout.beatPoints,
              isGroup: _isGroup,
              zoneDist: workout.zoneDist,
              isHistorical: true,
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: zoneColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _isGroup
                      ? Icons.groups_rounded
                      : Icons.directions_run_rounded,
                  color: zoneColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Strings.groupSoloLabel(workout.typeLabel),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodyLarge(
                        weight: FontWeight.w600,
                      ).copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _Pill(
                          icon: Icons.timer_outlined,
                          label: workout.durationLabel,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _Pill(
                          icon: Icons.favorite_rounded,
                          label: '${workout.avgHr} bpm',
                          color: zoneColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ZoneBadge(zone: workout.dominantZone, height: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _Pill({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: c),
        const SizedBox(width: 3),
        Text(label, style: AppTheme.caption(color: c)),
      ],
    );
  }
}

/// Shared row style for secondary home CTAs (currently just Solo workout).
class _JoinCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _JoinCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.brandRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: AppColors.brandRed),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.bodyLarge(weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTheme.caption()),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
