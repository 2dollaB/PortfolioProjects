import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../models/user_profile.dart';
import '../services/mock_data.dart';
import '../services/session_store.dart';
import '../widgets/beat_button.dart';
import '../widgets/home_header.dart';
import '../widgets/mobile_frame.dart';
import '../widgets/stat_chip.dart';
import '../widgets/workout_type_sheet.dart';
import 'all_sessions_screen.dart';
import 'session_detail_screen.dart';
import 'session_host_screen.dart';
import 'settings_screen.dart';
import 'trainer_monitor_screen.dart';

class TrainerHomeScreen extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback? onSignOut;
  const TrainerHomeScreen({
    super.key,
    required this.profile,
    this.onSignOut,
  });

  String _firstName() {
    final n = profile.name.trim();
    if (n.isEmpty) return 'Coach';
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
    return MobileFrame(
      child: Scaffold(
      backgroundColor: AppColors.darkBgPrimary,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl,
          ),
          children: [
            HomeHeader(
              greeting: _greeting(),
              name: _firstName(),
              subtitle: MockData.studioName,
              initials: 'CE',
              onAvatarTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    profile: profile,
                    onSignOut: onSignOut,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Live session OR start-new-session hero — reactive to SessionStore.
            ValueListenableBuilder<LiveSession?>(
              valueListenable: SessionStore.instance.live,
              builder: (context, live, _) {
                if (live != null) {
                  return _LiveSessionHero(live: live);
                }
                return _NoSessionHero();
              },
            ),

            const SizedBox(height: AppSpacing.xl),
            Text('Studio at a glance', style: AppTheme.h2()),
            const SizedBox(height: AppSpacing.sm),
            const _StudioStats(),

            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Text('Recent sessions', style: AppTheme.h2()),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AllSessionsScreen(),
                    ),
                  ),
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const _RecentSessionsList(),
          ],
        ),
      ),
      ),
    );
  }
}

class _StudioStats extends StatelessWidget {
  const _StudioStats();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: StatChip(label: 'Active today', value: '8')),
        SizedBox(width: AppSpacing.xs),
        Expanded(child: StatChip(label: 'Members', value: '34')),
        SizedBox(width: AppSpacing.xs),
        Expanded(child: StatChip(label: 'Sessions / wk', value: '12')),
      ],
    );
  }
}

class _RecentSessionsList extends StatelessWidget {
  const _RecentSessionsList();

  String _relativeDate(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return '${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<SessionRecord>>(
      valueListenable: SessionStore.instance.history,
      builder: (context, sessions, _) {
        if (sessions.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.darkBgSecondary,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Center(
              child: Text(
                'No sessions yet — start your first.',
                style: AppTheme.caption(),
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final s in sessions.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SessionDetailScreen(record: s),
                      ),
                    ),
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
                              color: AppColors.brandRed.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Icon(
                              s.type.icon,
                              color: AppColors.brandRed,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.name,
                                  style: AppTheme.bodyLarge(weight: FontWeight.w600)
                                      .copyWith(fontSize: 15),
                                ),
                                Text(
                                  '${_relativeDate(s.startedAt)} · ${s.athleteCount} athletes · ${s.durationLabel}',
                                  style: AppTheme.caption(),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${s.groupTrimp}',
                                style: AppTheme.statNumber(fontSize: 18),
                              ),
                              Text('TRIMP', style: AppTheme.micro()),
                            ],
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: AppColors.darkTextTertiary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Hero variants ──

class _LiveSessionHero extends StatelessWidget {
  final LiveSession live;
  const _LiveSessionHero({required this.live});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.xl),
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
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.brandRed,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'LIVE NOW',
                style: AppTheme.micro(color: AppColors.brandRed)
                    .copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            live.name,
            style: AppTheme.h1().copyWith(fontSize: 28),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${live.type.displayName} · ${live.athleteCount} athletes',
            style: AppTheme.bodyLarge(color: AppColors.darkTextSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          BeatPrimaryButton(
            label: 'Open session',
            icon: Icons.open_in_new_rounded,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const TrainerMonitorScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoSessionHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.darkBorder),
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
                  Icons.play_arrow_rounded,
                  color: AppColors.brandRed,
                  size: 16,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'READY TO TRAIN',
                style: AppTheme.micro(color: AppColors.brandRed)
                    .copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Start new session', style: AppTheme.h1().copyWith(fontSize: 28)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "Pick the type, set intervals, share the code — and you're live.",
            style: AppTheme.bodyLarge(color: AppColors.darkTextSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          BeatPrimaryButton(
            label: 'Create session',
            icon: Icons.add_circle_outline_rounded,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SessionHostScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
