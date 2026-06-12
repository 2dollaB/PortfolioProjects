import 'package:flutter/material.dart';
import '../widgets/mobile_frame.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../models/studio.dart';
import '../models/user_profile.dart';
import '../models/workout_summary.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/studio_repository.dart';
import '../services/workout_repository.dart';
import '../widgets/beat_button.dart';
import '../widgets/home_header.dart';
import 'edit_profile_screen.dart';

/// Athlete profile + settings â€” stats overview, then grouped settings sections.
class SettingsScreen extends StatefulWidget {
  final UserProfile? profile;
  final VoidCallback? onSignOut;
  const SettingsScreen({super.key, this.profile, this.onSignOut});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Studio? _studio;
  List<WorkoutSummary>? _workouts;

  bool get _production => AuthService.currentUid != null;

  @override
  void initState() {
    super.initState();
    final uid = AuthService.currentUid;
    if (uid == null) return;
    final sid = widget.profile?.studioId;
    if (sid != null) {
      StudioRepository.load(sid).then((s) {
        if (mounted) setState(() => _studio = s);
      }).catchError((_) {});
    }
    WorkoutRepository.fetchRecent(uid, limit: 200).then((w) {
      if (mounted) setState(() => _workouts = w);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile ?? MockData.athleteProfile;
    final studioName = _production ? _studio?.name : MockData.studioName;
    final workouts = _workouts;
    String workoutCount, totalTime;
    if (!_production) {
      workoutCount = '47';
      totalTime = '36h';
    } else if (workouts == null) {
      workoutCount = '–';
      totalTime = '–';
    } else {
      workoutCount = '${workouts.length}';
      final minutes = workouts.fold(0, (s, w) => s + w.durationMin);
      totalTime = '${(minutes / 60).round()}h';
    }
    // When pushed as a route (e.g. from the trainer home avatar), Navigator
    // can pop — show a back arrow. When mounted as a nav-shell tab, hide it.
    final canPop = Navigator.canPop(context);
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
            if (canPop)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.darkBgSecondary,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.darkBorder),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.darkTextPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Header card
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.darkBgSecondary,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.brandRed.withValues(alpha: 0.2),
                      border: Border.all(
                        color: AppColors.brandRed.withValues(alpha: 0.4),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      HomeHeader.initialsOf(p.name),
                      style: AppTheme.h1(color: AppColors.brandRed)
                          .copyWith(fontWeight: FontWeight.w700, fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name.isEmpty ? 'Athlete' : p.name,
                          style: AppTheme.h2(),
                        ),
                        if (studioName != null)
                          Text(studioName, style: AppTheme.caption()),
                        const SizedBox(height: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            p.role.displayName,
                            style: AppTheme.micro(color: AppColors.success)
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Quick stats
            Row(
              children: [
                Expanded(child: _StatBlock(label: 'Workouts', value: workoutCount)),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: _StatBlock(label: 'Total time', value: totalTime)),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: _StatBlock(label: 'HR max', value: '${p.hrMax}')),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            _Section(title: 'Account', items: [
              _SettingItem(
                icon: Icons.person_outline_rounded,
                label: 'Personal info',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(profile: p),
                  ),
                ),
              ),
              const _SettingItem(
                icon: Icons.favorite_outline_rounded,
                label: 'Health data',
              ),
              const _SettingItem(
                icon: Icons.bluetooth_rounded,
                label: 'Connected devices',
                trailing: 'Polar H10',
              ),
            ]),

            _Section(title: 'App', items: const [
              _SettingItem(icon: Icons.notifications_none_rounded, label: 'Notifications'),
              _SettingItem(icon: Icons.dark_mode_outlined, label: 'Appearance', trailing: 'Dark'),
              _SettingItem(icon: Icons.language_rounded, label: 'Language', trailing: 'English'),
              _SettingItem(icon: Icons.straighten_rounded, label: 'Units', trailing: 'Metric'),
            ]),

            _Section(title: 'Studio', items: [
              _SettingItem(
                icon: Icons.groups_rounded,
                label: 'My studio',
                trailing: _production
                    ? (_studio?.name ??
                        (p.studioId == null ? 'None yet' : '–'))
                    : 'Pulse Studio',
              ),
              const _SettingItem(
                  icon: Icons.workspace_premium_outlined,
                  label: 'Subscription',
                  trailing: 'Free'),
            ]),

            _Section(title: 'Support', items: const [
              _SettingItem(icon: Icons.help_outline_rounded, label: 'Help & FAQ'),
              _SettingItem(icon: Icons.shield_outlined, label: 'Privacy policy'),
              _SettingItem(icon: Icons.description_outlined, label: 'Terms of service'),
            ]),

            const SizedBox(height: AppSpacing.lg),
            BeatSecondaryButton(
              label: 'Sign out',
              icon: Icons.logout_rounded,
              onPressed: () {
                // Pop any pushed routes (athlete/trainer settings is pushed
                // from home avatar tap), then bubble up to the prototype flow.
                Navigator.of(context).popUntil((r) => r.isFirst);
                widget.onSignOut?.call();
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Text(
                'BeatSync · v1.0.0 (prototype)',
                style: AppTheme.micro(),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  const _StatBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm, vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        children: [
          Text(value, style: AppTheme.statNumber(fontSize: 22)),
          const SizedBox(height: 2),
          Text(label, style: AppTheme.micro()),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<_SettingItem> items;
  const _Section({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs, bottom: AppSpacing.xs,
            ),
            child: Text(
              title.toUpperCase(),
              style: AppTheme.micro().copyWith(letterSpacing: 1.4),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.darkBgSecondary,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  items[i],
                  if (i < items.length - 1)
                    const Divider(
                      color: AppColors.darkBorder,
                      height: 1,
                      indent: 52,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback? onTap;
  const _SettingItem({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.darkTextSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(label, style: AppTheme.bodyLarge())),
              if (trailing != null) ...[
                Text(trailing!, style: AppTheme.caption()),
                const SizedBox(width: AppSpacing.xs),
              ],
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: AppColors.darkTextTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}