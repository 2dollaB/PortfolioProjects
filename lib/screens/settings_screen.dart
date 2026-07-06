import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/account_deletion_service.dart';
import '../widgets/mobile_frame.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../models/studio.dart';
import '../models/user_profile.dart';
import '../models/workout_summary.dart';
import '../services/auth_service.dart';
import '../services/ble_hr_service.dart';
import '../services/mock_data.dart';
import '../services/studio_repository.dart';
import '../services/user_repository.dart';
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
  StreamSubscription? _workoutsSub;

  /// Live copy of the profile. Synced from the parent when this screen is a
  /// nav-shell tab, and from EditProfileScreen's onSaved when it's a pushed
  /// route (trainer avatar) — a pushed route never gets new constructor
  /// props, so edits would otherwise show stale data on re-entry.
  UserProfile? _profile;

  bool get _production => AuthService.currentUid != null;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    final uid = AuthService.currentUid;
    if (uid == null) return;
    // Refresh from Firestore (instant via local cache) — the constructor
    // profile can be stale when this screen is pushed from an old route.
    UserRepository.load(uid).then((fresh) {
      if (fresh != null && mounted) setState(() => _profile = fresh);
    }).catchError((_) {});
    _loadStudio();
    // Stream, not one-shot: the tab stays alive in the IndexedStack, so a
    // fetch here would show pre-workout stats until app restart (E2E-2).
    _workoutsSub = WorkoutRepository.watchRecent(uid, limit: 200).listen(
      (w) {
        if (mounted) setState(() => _workouts = w);
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _workoutsSub?.cancel();
    super.dispose();
  }

  /// Store-required account deletion: warning + password re-auth in one
  /// dialog, then a full data wipe via [AccountDeletionService].
  Future<void> _confirmDeleteAccount() async {
    final passwordCtrl = TextEditingController();
    var busy = false;
    String? error;
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(Strings.deleteAccount),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Strings.deleteAccountWarning, style: AppTheme.body()),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                enabled: !busy,
                decoration: InputDecoration(
                  hintText: Strings.deleteAccountPasswordHint,
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(error!, style: AppTheme.caption(color: AppColors.danger)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.of(dialogContext).pop(false),
              child: Text(Strings.cancel),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      setDialogState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await AccountDeletionService.deleteAccount(
                          password: passwordCtrl.text,
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop(true);
                        }
                      } on FirebaseAuthException {
                        setDialogState(() {
                          busy = false;
                          error = Strings.deleteAccountWrongPassword;
                        });
                      } catch (_) {
                        setDialogState(() {
                          busy = false;
                          error = Strings.deleteAccountFailed;
                        });
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      Strings.deleteAccountConfirm,
                      style: AppTheme.body(color: AppColors.danger)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
    passwordCtrl.dispose();
    if (deleted == true && mounted) {
      // Auth user is gone — route back to login like a sign-out.
      Navigator.of(context).popUntil((r) => r.isFirst);
      widget.onSignOut?.call();
    }
  }

  @override
  void didUpdateWidget(SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Joining/leaving a studio changes studioId on the live profile —
    // refresh the studio row instead of showing the initState-era value.
    final studioChanged =
        widget.profile?.studioId != oldWidget.profile?.studioId;
    _profile = widget.profile;
    if (studioChanged) {
      setState(() => _studio = null);
      _loadStudio();
    }
  }

  void _loadStudio() {
    final sid = _profile?.studioId;
    if (sid == null) return;
    StudioRepository.load(sid).then((s) {
      if (mounted) setState(() => _studio = s);
    }).catchError((_) {});
  }

  String _themeLabel(ThemeMode m) => switch (m) {
        ThemeMode.light => Strings.themeLight,
        ThemeMode.dark => Strings.themeDark,
        ThemeMode.system => Strings.themeSystem,
      };

  String get _themeModeLabel => _themeLabel(
      BeatSyncApp.appKey.currentState?.themeMode ?? ThemeMode.dark);

  void _setThemeMode(ThemeMode mode) {
    BeatSyncApp.appKey.currentState?.setThemeMode(mode);
    if (mounted) setState(() {}); // refresh the trailing label
  }

  void _setLang(AppLang lang) {
    BeatSyncApp.appKey.currentState?.setLang(lang);
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
              (ThemeMode.light, Icons.light_mode_outlined),
              (ThemeMode.dark, Icons.dark_mode_outlined),
              (ThemeMode.system, Icons.brightness_auto_outlined),
            ])
              ListTile(
                leading: Icon(opt.$2, color: AppColors.textSecondary),
                title: Text(_themeLabel(opt.$1), style: AppTheme.bodyLarge()),
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
            for (final l in AppLang.values)
              ListTile(
                leading:
                    Icon(Icons.translate_rounded, color: AppColors.textSecondary),
                title: Text(l.label, style: AppTheme.bodyLarge()),
                trailing: Strings.lang == l
                    ? const Icon(Icons.check_rounded, color: AppColors.brandRed)
                    : null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _setLang(l);
                },
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
    final sid = _profile?.studioId;
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
    final p = _profile ?? MockData.athleteProfile;
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
                          p.name.isEmpty ? Strings.athlete : p.name,
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
                            p.role == UserRole.trainer
                                ? Strings.trainer
                                : Strings.athlete,
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

            // Quick stats — IntrinsicHeight keeps the three cards level even
            // when a label ("Ukupno vrijeme") is longer than its neighbours.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _StatBlock(label: Strings.workouts, value: workoutCount)),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: _StatBlock(label: Strings.totalTime, value: totalTime)),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _StatBlock(
                      label: Strings.hrMax,
                      value: '${p.hrMax}',
                      infoTitle: Strings.hrMaxInfoTitle,
                      infoBody: Strings.hrMaxInfoBody,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            _Section(title: Strings.account, items: [
              _SettingItem(
                icon: Icons.person_outline_rounded,
                label: Strings.personalInfo,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EditProfileScreen(
                      profile: p,
                      onSaved: (updated) =>
                          setState(() => _profile = updated),
                    ),
                  ),
                ),
              ),
              _SettingItem(
                icon: Icons.favorite_outline_rounded,
                label: Strings.healthData,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HealthDataScreen(profile: p),
                  ),
                ),
              ),
              _SettingItem(
                icon: Icons.bluetooth_rounded,
                label: Strings.connectedDevices,
                trailing: _production
                    ? (BleHrService.instance.connectedDeviceName ?? Strings.none)
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

            _Section(title: Strings.app, items: [
              _SettingItem(
                icon: Icons.dark_mode_outlined,
                label: Strings.appearance,
                trailing: _themeModeLabel,
                onTap: _showAppearanceSheet,
              ),
              _SettingItem(
                icon: Icons.language_rounded,
                label: Strings.language,
                trailing: Strings.lang.label,
                onTap: _showLanguageSheet,
              ),
            ]),

            _Section(title: Strings.studio, items: [
              _SettingItem(
                icon: Icons.groups_rounded,
                label: Strings.myStudio,
                trailing: _production
                    ? (_studio?.name ??
                        (p.studioId == null ? Strings.noStudioYet : '–'))
                    : 'Pulse Studio',
                onTap: _production ? () => _openStudio(p) : null,
              ),
              _SettingItem(
                icon: Icons.workspace_premium_outlined,
                label: Strings.subscription,
                trailing: Strings.free,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                ),
              ),
            ]),

            _Section(title: Strings.support, items: [
              _SettingItem(
                icon: Icons.help_outline_rounded,
                label: Strings.helpFaq,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HelpFaqScreen()),
                ),
              ),
              _SettingItem(
                icon: Icons.shield_outlined,
                label: Strings.privacyPolicy,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => LegalDocScreen.privacy()),
                ),
              ),
              _SettingItem(
                icon: Icons.description_outlined,
                label: Strings.termsOfService,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => LegalDocScreen.terms()),
                ),
              ),
            ]),

            const SizedBox(height: AppSpacing.lg),
            BeatSecondaryButton(
              label: Strings.signOut,
              icon: Icons.logout_rounded,
              onPressed: () {
                // Pop any pushed routes (athlete/trainer settings is pushed
                // from home avatar tap), then bubble up to the prototype flow.
                Navigator.of(context).popUntil((r) => r.isFirst);
                widget.onSignOut?.call();
              },
            ),
            if (_production) ...[
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: TextButton(
                  onPressed: _confirmDeleteAccount,
                  child: Text(
                    Strings.deleteAccount,
                    style: AppTheme.caption(color: AppColors.danger),
                  ),
                ),
              ),
            ],
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
  /// When set, the block is tappable and opens an info dialog (e.g. how
  /// HR max is estimated). A small info icon appears next to the label.
  final String? infoTitle;
  final String? infoBody;
  const _StatBlock({
    required this.label,
    required this.value,
    this.infoTitle,
    this.infoBody,
  });

  @override
  Widget build(BuildContext context) {
    final block = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm, vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: AppTheme.statNumber(fontSize: 22)),
          const SizedBox(height: 2),
          // Single line, scaled down if needed — a wrapped label made the
          // middle card taller than its neighbours.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                Text(label, style: AppTheme.micro(), maxLines: 1),
                if (infoTitle != null) ...[
                  const SizedBox(width: 3),
                  Icon(Icons.info_outline_rounded,
                      size: 12, color: AppColors.textSecondary),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    if (infoTitle == null) return block;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(infoTitle!),
          content: SingleChildScrollView(
            child: Text(infoBody ?? '', style: AppTheme.bodyLarge()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(Strings.done),
            ),
          ],
        ),
      ),
      child: block,
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