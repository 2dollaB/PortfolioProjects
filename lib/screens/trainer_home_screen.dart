import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../models/user_profile.dart';
import '../services/mock_data.dart';
import '../widgets/beat_button.dart';
import '../widgets/home_header.dart';
import '../widgets/stat_chip.dart';
import 'session_host_screen.dart';
import 'settings_screen.dart';
import 'trainer_monitor_screen.dart';

class TrainerHomeScreen extends StatelessWidget {
  final UserProfile profile;
  const TrainerHomeScreen({super.key, required this.profile});

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
    return Scaffold(
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
                  builder: (_) => SettingsScreen(profile: profile),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Active session hero
            Container(
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
                        width: 8,
                        height: 8,
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
                    'Friday HIIT 18:00',
                    style: AppTheme.h1().copyWith(fontSize: 28),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${MockData.liveSession.length} athletes · Round 3 / 8',
                    style: AppTheme.bodyLarge(color: AppColors.darkTextSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: const [
                      Expanded(child: StatChip(label: 'Avg HR', value: '148', unit: 'bpm')),
                      SizedBox(width: AppSpacing.xs),
                      Expanded(child: StatChip(label: 'In Z4+', value: '7', unit: '/10')),
                      SizedBox(width: AppSpacing.xs),
                      Expanded(child: StatChip(label: 'Elapsed', value: '24:18')),
                    ],
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
            ),
            const SizedBox(height: AppSpacing.lg),

            BeatSecondaryButton(
              label: 'Start new session',
              icon: Icons.add_circle_outline_rounded,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SessionHostScreen(),
                ),
              ),
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
                TextButton(onPressed: () {}, child: const Text('See all')),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const _RecentSessionsList(),
          ],
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

  @override
  Widget build(BuildContext context) {
    final sessions = [
      ('HIIT 18:00', 'Today', '14 athletes', '92'),
      ('Strength', 'Yesterday', '9 athletes', '68'),
      ('Endurance Run', 'Mon 19', '12 athletes', '104'),
    ];
    return Column(
      children: [
        for (final s in sessions)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
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
                  child: const Icon(Icons.groups_rounded,
                      color: AppColors.brandRed, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.$1,
                          style: AppTheme.bodyLarge(weight: FontWeight.w600)
                              .copyWith(fontSize: 15)),
                      Text('${s.$2} · ${s.$3}', style: AppTheme.caption()),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(s.$4,
                        style: AppTheme.statNumber(fontSize: 18)),
                    Text('TRIMP', style: AppTheme.micro()),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
