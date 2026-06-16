import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/hr_zones.dart';
import '../config/theme.dart';
import '../models/user_profile.dart';
import '../models/workout_summary.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/workout_repository.dart';
import '../widgets/beat_button.dart';
import '../widgets/home_header.dart';
import '../widgets/mobile_frame.dart';
import '../widgets/stat_chip.dart';
import '../widgets/workout_type_sheet.dart';
import '../widgets/zone_badge.dart';
import 'workout_screen.dart';
import 'workout_history_screen.dart';
import 'join_session_screen.dart';
import 'join_studio_screen.dart';
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
    if (n.isEmpty) return 'Athlete';
    return n.split(RegExp(r'\s+')).first;
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
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
                  AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl,
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

            // JOIN A STUDIO — shown only until the athlete belongs to one
            if (enableStudioJoin && profile.studioId == null)
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.sm,
                ),
                sliver: SliverToBoxAdapter(child: _JoinStudioCard()),
              ),

            // HERO — Start workout card
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              sliver: SliverToBoxAdapter(
                child: _HeroCard(
                  profile: profile,
                  last: (workouts == null || workouts.isEmpty)
                      ? null
                      : workouts.first,
                ),
              ),
            ),

            // JOIN GROUP SESSION — directly under Start so it's the second-most-prominent CTA
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, 0,
              ),
              sliver: SliverToBoxAdapter(
                child: _JoinSessionCard(profile: profile),
              ),
            ),

            // STATS THIS WEEK
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xs,
              ),
              sliver: SliverToBoxAdapter(child: _SectionHeader('This week')),
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
                AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xs,
              ),
              sliver: SliverToBoxAdapter(
                child: _SectionHeader(
                  'Recent workouts',
                  trailing: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const WorkoutHistoryScreen(),
                      ),
                    ),
                    child: const Text('See all'),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              sliver: SliverToBoxAdapter(
                child: _RecentList(workouts: workouts?.take(3).toList()),
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

class _HeroCard extends StatelessWidget {
  final UserProfile profile;
  final WorkoutSummary? last;
  const _HeroCard({required this.profile, required this.last});

  @override
  Widget build(BuildContext context) {
    final last = this.last;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E1E24),
            Color(0xFF16161A),
          ],
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
                  Icons.favorite_rounded,
                  color: AppColors.brandRed,
                  size: 16,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'READY WHEN YOU ARE',
                style: AppTheme.micro(color: AppColors.brandRed)
                    .copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Start workout',
              style: AppTheme.h1().copyWith(fontSize: 32, height: 1.1)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "We'll connect your HR strap and pick up where you left off.",
            style: AppTheme.bodyLarge(color: AppColors.textSecondary),
          ),
          if (last != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.bgPrimary.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.history_rounded,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.xs),
                  Text('Last session · ', style: AppTheme.caption()),
                  Text(last.dateLabel,
                      style:
                          AppTheme.caption(color: AppColors.textPrimary)),
                  const Spacer(),
                  Text('${last.avgHr} ',
                      style: AppTheme.statNumber(fontSize: 14)),
                  Text('avg · ${last.durationLabel}',
                      style: AppTheme.caption()),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          BeatPrimaryButton(
            label: 'Start workout',
            icon: Icons.play_arrow_rounded,
            onPressed: () async {
              final type = await WorkoutTypeSheet.show(context);
              if (type == null || !context.mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WorkoutScreen(
                    profile: profile,
                    workoutType: type,
                  ),
                ),
              );
            },
          ),
        ],
      ),
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
    var sessions = '–', time = '–', trimp = '–';
    if (all != null) {
      final now = DateTime.now();
      // Same rolling-7-day window as the history screen's "This week" filter.
      final week =
          all.where((w) => now.difference(w.startTime).inDays <= 7).toList();
      final minutes = week.fold(0, (sum, w) => sum + w.durationMin);
      final h = minutes ~/ 60;
      final m = minutes % 60;
      sessions = '${week.length}';
      time = h > 0 ? '${h}h ${m}m' : '${m}m';
      trimp = '${week.fold(0, (sum, w) => sum + w.trimp)}';
    }
    return Row(
      children: [
        Expanded(
            child: StatChip(label: 'Sessions', value: sessions, unit: 'this week')),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: StatChip(label: 'Time', value: time)),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: StatChip(label: 'TRIMP', value: trimp)),
      ],
    );
  }
}

class _RecentList extends StatelessWidget {
  /// Null while the production stream is still loading.
  final List<WorkoutSummary>? workouts;
  const _RecentList({required this.workouts});

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
            'No workouts yet.\nFinish a session and it shows up here.',
            style: AppTheme.caption(),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final w in all) ...[
          _WorkoutRow(workout: w),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _WorkoutRow extends StatelessWidget {
  final WorkoutSummary workout;
  const _WorkoutRow({required this.workout});

  @override
  Widget build(BuildContext context) {
    final zoneColor = AppColors.zoneColor(workout.dominantZone);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
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
                child: Icon(_iconFor(workout.type), color: zoneColor, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(workout.typeLabel,
                            style: AppTheme.bodyLarge(weight: FontWeight.w600)
                                .copyWith(fontSize: 15)),
                        const SizedBox(width: AppSpacing.xs),
                        Text('· ${workout.dateLabel}',
                            style: AppTheme.caption()),
                      ],
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

  IconData _iconFor(String type) {
    switch (type.toLowerCase()) {
      case 'hiit':
        return Icons.bolt_rounded;
      case 'strength':
        return Icons.fitness_center_rounded;
      case 'cardio':
      case 'endurance':
        return Icons.directions_run_rounded;
      case 'cycling':
        return Icons.directions_bike_rounded;
      case 'yoga':
        return Icons.self_improvement_rounded;
      case 'crossfit':
        return Icons.local_fire_department_rounded;
      default:
        return Icons.directions_run_rounded;
    }
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

/// CTA shown on the athlete home until they belong to a studio.
class _JoinStudioCard extends StatelessWidget {
  const _JoinStudioCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const JoinStudioScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.brandRed.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.brandRed.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.brandRed.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.group_add_rounded,
                    color: AppColors.brandRed),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Join a studio',
                        style: AppTheme.bodyLarge(weight: FontWeight.w700)),
                    Text("Enter your trainer's 6-digit code",
                        style: AppTheme.caption()),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinSessionCard extends StatelessWidget {
  final UserProfile profile;
  const _JoinSessionCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => JoinSessionScreen(profile: profile),
          ),
        ),
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
                  color: HrZones.colors[2]!.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(Icons.qr_code_scanner_rounded,
                    color: HrZones.colors[2]),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Join a group session',
                        style: AppTheme.bodyLarge(weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      'Scan the QR from your trainer',
                      style: AppTheme.caption(),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
