import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../models/studio.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/session_store.dart';
import '../services/studio_repository.dart';
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
    final studioId = AuthService.currentUid == null ? null : profile.studioId;
    if (studioId == null) return _buildHome(context, production: false);
    return StreamBuilder<Studio?>(
      stream: StudioRepository.watch(studioId),
      builder: (context, snap) =>
          _buildHome(context, production: true, studio: snap.data),
    );
  }

  /// [studio] is null in demo mode or while the production stream is loading.
  Widget _buildHome(
    BuildContext context, {
    required bool production,
    Studio? studio,
  }) {
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
              subtitle: production ? studio?.name : MockData.studioName,
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
            // Active today / sessions-per-week need cloud sessions (not built
            // yet) — production shows '–' until then.
            production
                ? _StudioStats(
                    activeToday: '–',
                    members:
                        studio == null ? '–' : '${studio.athleteUids.length}',
                    sessionsPerWeek: '–',
                  )
                : const _StudioStats(
                    activeToday: '8',
                    members: '34',
                    sessionsPerWeek: '12',
                  ),

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
  final String activeToday;
  final String members;
  final String sessionsPerWeek;
  const _StudioStats({
    required this.activeToday,
    required this.members,
    required this.sessionsPerWeek,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: StatChip(label: 'Active today', value: activeToday)),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: StatChip(label: 'Members', value: members)),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: StatChip(label: 'Sessions / wk', value: sessionsPerWeek)),
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
