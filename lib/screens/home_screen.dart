import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/hr_zones.dart';
import '../config/theme.dart';
import '../models/user_profile.dart';
import '../services/mock_data.dart';
import '../widgets/beat_button.dart';
import '../widgets/home_header.dart';
import '../widgets/mobile_frame.dart';
import '../widgets/stat_chip.dart';
import '../widgets/workout_type_sheet.dart';
import '../widgets/zone_badge.dart';
import 'workout_screen.dart';
import 'workout_history_screen.dart';
import 'join_session_screen.dart';
import 'settings_screen.dart';

/// Athlete home — greeting, hero "Start Workout" card, recent workouts strip,
/// weekly stats. Designed as the first impression of the app.
class HomeScreen extends StatelessWidget {
  final UserProfile profile;
  // ignore: unused_element_parameter
  final void Function(UserProfile)? onProfileUpdated;
  final VoidCallback? onSignOut;

  const HomeScreen({
    super.key,
    required this.profile,
    this.onProfileUpdated,
    this.onSignOut,
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

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
      backgroundColor: AppColors.darkBgPrimary,
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
                  initials: _initials(profile.name),
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

            // HERO — Start workout card
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              sliver: SliverToBoxAdapter(child: _HeroCard(profile: profile)),
            ),

            // JOIN GROUP SESSION — directly under Start so it's the second-most-prominent CTA
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, 0,
              ),
              sliver: SliverToBoxAdapter(child: const _JoinSessionCard()),
            ),

            // STATS THIS WEEK
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.xs,
              ),
              sliver: SliverToBoxAdapter(child: _SectionHeader('This week')),
            ),
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              sliver: SliverToBoxAdapter(child: _WeeklyStats()),
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
                child: _RecentList(workouts: MockData.recentWorkouts.take(3).toList()),
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
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final UserProfile profile;
  const _HeroCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final last = MockData.recentWorkouts.first;
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
        border: Border.all(color: AppColors.darkBorder),
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
            style: AppTheme.bodyLarge(color: AppColors.darkTextSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.darkBgPrimary.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.history_rounded,
                    size: 16, color: AppColors.darkTextSecondary),
                const SizedBox(width: AppSpacing.xs),
                Text('Last session · ', style: AppTheme.caption()),
                Text(last.date,
                    style: AppTheme.caption(color: AppColors.darkTextPrimary)),
                const Spacer(),
                Text('${last.avgBpm} ', style: AppTheme.statNumber(fontSize: 14)),
                Text('avg · ${last.durationLabel}', style: AppTheme.caption()),
              ],
            ),
          ),
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
  const _WeeklyStats();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: StatChip(label: 'Sessions', value: '4', unit: 'this week')),
        SizedBox(width: AppSpacing.xs),
        Expanded(child: StatChip(label: 'Time', value: '3h 27m')),
        SizedBox(width: AppSpacing.xs),
        Expanded(child: StatChip(label: 'TRIMP', value: '368')),
      ],
    );
  }
}

class _RecentList extends StatelessWidget {
  final List<MockWorkout> workouts;
  const _RecentList({required this.workouts});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final w in workouts) ...[
          _WorkoutRow(workout: w),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _WorkoutRow extends StatelessWidget {
  final MockWorkout workout;
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
            color: AppColors.darkBgSecondary,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.darkBorder),
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
                        Text(workout.type,
                            style: AppTheme.bodyLarge(weight: FontWeight.w600)
                                .copyWith(fontSize: 15)),
                        const SizedBox(width: AppSpacing.xs),
                        Text('· ${workout.date}', style: AppTheme.caption()),
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
                          label: '${workout.avgBpm} bpm',
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
      case 'endurance':
        return Icons.directions_run_rounded;
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
    final c = color ?? AppColors.darkTextSecondary;
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

class _JoinSessionCard extends StatelessWidget {
  const _JoinSessionCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const JoinSessionScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.darkBgSecondary,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.darkBorder),
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
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppColors.darkTextSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
