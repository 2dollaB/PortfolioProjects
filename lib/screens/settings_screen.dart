import 'package:flutter/material.dart';
import '../widgets/mobile_frame.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../models/studio.dart';
import '../models/user_profile.dart';
import '../models/workout_summary.dart';
import '../services/auth_service.dart';
import '../services/ble_hr_service.dart';
import '../services/mock_data.dart';
import '../services/studio_repository.dart';
import '../services/workout_repository.dart';
import '../widgets/beat_button.dart';
import '../widgets/home_header.dart';
import '../main.dart';
import 'device_pairing_screen.dart';
import 'edit_profile_screen.dart';
import 'health_data_screen.dart';
import 'help_faq_screen.dart';
import 'join_studio_screen.dart';
import 'legal_doc_screen.dart';
import 'studio_detail_screen.dart';
import 'subscription_screen.dart';

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

  String get _themeModeLabel {
    switch (BeatSyncApp.appKey.currentState?.themeMode ?? ThemeMode.dark) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  void _setThemeMode(ThemeMode mode) {
    BeatSyncApp.appKey.currentState?.setThemeMode(mode);
    if (mounted) setState(() {}); // refresh the trailing label
  }

  void _showAppearanceSheet() {
    final current =
        BeatSyncApp.appKey.currentState?.themeMode ?? ThemeMode.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            for (final opt in const [
              (ThemeMode.light, 'Light', Icons.light_mode_outlined),
              (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
              (ThemeMode.system, 'System', Icons.brightness_auto_outlined),
            ])
              ListTile(
                leading: Icon(opt.$3, color: AppColors.textSecondary),
                title: Text(opt.$2, style: AppTheme.bodyLarge()),
                trailing: current == opt.$1
                    ? const Icon(Icons.check_rounded, color: AppColors.brandRed)
                    : null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _setThemeMode(opt.$1);
                },
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  void _showLanguageSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              leading: const Icon(Icons.check_rounded, color: AppColors.brandRed),
              title: Text('English', style: AppTheme.bodyLarge()),
              onTap: () => Navigator.of(ctx).pop(),
            ),
            ListTile(
              enabled: false,
              leading: Icon(Icons.translate_rounded,
                  color: AppColors.textTertiary),
              title: Text('Hrvatski',
                  style: AppTheme.bodyLarge(color: AppColors.textTertiary)),
              trailing: Text('Coming soon', style: AppTheme.caption()),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  void _openStudio(UserProfile p) {
    final sid = _studio?.id ?? p.studioId;
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => sid != null
              ? StudioDetailScreen(studioId: sid)
              : const JoinStudioScreen(),
        ))
        .then((_) => _reloadStudio());
  }

  void _reloadStudio() {
    final sid = widget.profile?.studioId;
    if (sid == null) {
      if (mounted) setState(() => _studio = null);
      return;
    }
    StudioRepository.load(sid).then((s) {
      if (mounted) setState(() => _studio = s);
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
      backgroundColor: AppColors.bgPrimary,
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
                          color: AppColors.bgSecondary,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.textPrimary,
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
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.border),
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
              _SettingItem(
                icon: Icons.favorite_outline_rounded,
                label: 'Health data',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HealthDataScreen(profile: p),
                  ),
                ),
              ),
              _SettingItem(
                icon: Icons.bluetooth_rounded,
                label: 'Connected devices',
                trailing: _production
                    ? (BleHrService.instance.connectedDeviceName ?? 'None')
                    : 'Polar H10',
                onTap: _production
                    ? () => Navigator.of(context)
                        .push(MaterialPageRoute(
                          builder: (_) => const DevicePairingScreen(),
                        ))
                        // Refresh the trailing label after pairing.
                        .then((_) => mounted ? setState(() {}) : null)
                    : null,
              ),
            ]),

            _Section(title: 'App', items: [
              _SettingItem(
                icon: Icons.dark_mode_outlined,
                label: 'Appearance',
                trailing: _themeModeLabel,
                onTap: _showAppearanceSheet,
              ),
              _SettingItem(
                icon: Icons.language_rounded,
                label: 'Language',
                trailing: 'English',
                onTap: _showLanguageSheet,
              ),
            ]),

            _Section(title: 'Studio', items: [
              _SettingItem(
                icon: Icons.groups_rounded,
                label: 'My studio',
                trailing: _production
                    ? (_studio?.name ??
                        (p.studioId == null ? 'None yet' : '–'))
                    : 'Pulse Studio',
                onTap: _production ? () => _openStudio(p) : null,
              ),
              _SettingItem(
                icon: Icons.workspace_premium_outlined,
                label: 'Subscription',
                trailing: 'Free',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                ),
              ),
            ]),

            _Section(title: 'Support', items: [
              _SettingItem(
                icon: Icons.help_outline_rounded,
                label: 'Help & FAQ',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HelpFaqScreen()),
                ),
              ),
              _SettingItem(
                icon: Icons.shield_outlined,
                label: 'Privacy policy',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => LegalDocScreen.privacy()),
                ),
              ),
              _SettingItem(
                icon: Icons.description_outlined,
                label: 'Terms of service',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => LegalDocScreen.terms()),
                ),
              ),
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
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
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
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  items[i],
                  if (i < items.length - 1)
                    Divider(
                      color: AppColors.border,
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
              Icon(icon, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(label, style: AppTheme.bodyLarge())),
              if (trailing != null) ...[
                Text(trailing!, style: AppTheme.caption()),
                const SizedBox(width: AppSpacing.xs),
              ],
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}