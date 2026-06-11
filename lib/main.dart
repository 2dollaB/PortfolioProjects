import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/app_colors.dart';
import 'config/feature_flags.dart';
import 'config/theme.dart';
import 'models/user_profile.dart';
import 'screens/login_screen.dart';
import 'screens/main_nav_shell.dart';
import 'screens/onboarding_tutorial_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/register_screen.dart';
import 'screens/role_select_screen.dart';
import 'screens/splash_screen.dart';
import 'services/mock_data.dart';

Future<void> _initHeavyServices() async {
  if (FeatureFlags.prototypeMode) return;
  if (kIsWeb) return;
  // Real BLE/notifications/foreground init lives in services/ — kept out of the
  // demo entrypoint so the prototype loads in any browser with zero friction.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initHeavyServices();

  SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.darkBgPrimary,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  ThemeMode initialThemeMode = ThemeMode.dark;
  if (!FeatureFlags.prototypeMode && !kIsWeb) {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('theme_mode');
    initialThemeMode = saved == 'light'
        ? ThemeMode.light
        : saved == 'system'
            ? ThemeMode.system
            : ThemeMode.dark;
  }

  runApp(BeatSyncApp(initialThemeMode: initialThemeMode));
}

class BeatSyncApp extends StatefulWidget {
  final ThemeMode initialThemeMode;

  const BeatSyncApp({super.key, this.initialThemeMode = ThemeMode.dark});

  static final GlobalKey<BeatSyncAppState> appKey = GlobalKey<BeatSyncAppState>();

  @override
  State<BeatSyncApp> createState() => BeatSyncAppState();
}

class BeatSyncAppState extends State<BeatSyncApp> {
  late ThemeMode _themeMode = widget.initialThemeMode;

  void setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: BeatSyncApp.appKey,
      title: 'BeatSync',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: FeatureFlags.prototypeMode
          ? const _PrototypeFlow()
          : const _ProductionFlow(),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// PROTOTYPE FLOW
//
// Splash → Onboarding (2 slides, skippable) → Login
//   ├─ Login success (matched email) → MainNavShell(role)
//   └─ Sign up
//        → Role select
//        → Profile setup (2 pages)
//        → if trainer: Studio creation
//        → MainNavShell(role)
//
// Sign-out anywhere routes back to Login (preserving onboarding-seen).
// ──────────────────────────────────────────────────────────────────────
class _PrototypeFlow extends StatefulWidget {
  const _PrototypeFlow();

  @override
  State<_PrototypeFlow> createState() => _PrototypeFlowState();
}

enum _Step {
  splash,
  onboarding,
  login,
  register,
  roleSelect,
  profileSetup,
  home,
}

class _PrototypeFlowState extends State<_PrototypeFlow> {
  _Step _step = _Step.splash;
  UserRole _role = UserRole.athlete;
  bool _onboardingDone = false;
  String? _registeredName;

  /// Once the wizard finishes, we know the role they picked inside it.
  /// We don't track wizard state here — the wizard just calls onComplete.
  UserProfile get _profile => _role == UserRole.trainer
      ? MockData.trainerProfile
      : MockData.athleteProfile;

  void _signOut() {
    setState(() => _step = _Step.login);
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _Step.splash:
        return SplashScreen(
          onDone: () => setState(() => _step = _onboardingDone
              ? _Step.login
              : _Step.onboarding),
        );

      case _Step.onboarding:
        return OnboardingTutorialScreen(
          onComplete: () => setState(() {
            _onboardingDone = true;
            _step = _Step.login;
          }),
        );

      case _Step.login:
        return LoginScreen(
          onSignedIn: (role) {
            setState(() {
              _role = role;
              _step = _Step.home;
            });
          },
          onCreateAccount: () => setState(() => _step = _Step.register),
        );

      case _Step.register:
        return RegisterScreen(
          onRegistered: (name) => setState(() {
            _registeredName = name;
            _step = _Step.roleSelect;
          }),
          onBackToLogin: () => setState(() => _step = _Step.login),
        );

      case _Step.roleSelect:
        // Dedicated step right after register — not counted as part of the
        // wizard's progress (athlete = 3 / trainer = 5 inside the wizard).
        return RoleSelectScreen(
          onSelected: (role) => setState(() {
            _role = role;
            _step = _Step.profileSetup;
          }),
        );

      case _Step.profileSetup:
        // Wizard runs 3 pages for athlete (Personal · Fitness · Strap) or
        // 5 for trainer (+ Studio form + Studio success). It doesn't pick role.
        return ProfileSetupScreen(
          initialName: _registeredName,
          role: _role,
          onComplete: (role) => setState(() {
            _role = role;
            _step = _Step.home;
          }),
        );

      case _Step.home:
        return MainNavShell(
          profile: _profile,
          onSignOut: _signOut,
        );
    }
  }
}

// ──────────────────────────────────────────────────────────────────────
// PRODUCTION FLOW (kept for when FeatureFlags.prototypeMode is false)
// ──────────────────────────────────────────────────────────────────────
class _ProductionFlow extends StatefulWidget {
  const _ProductionFlow();

  @override
  State<_ProductionFlow> createState() => _ProductionFlowState();
}

class _ProductionFlowState extends State<_ProductionFlow> {
  bool _bootstrapped = false;
  UserProfile? _profile;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _profile = MockData.athleteProfile;
      _showOnboarding = false;
      _bootstrapped = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_bootstrapped) {
      return const Scaffold(
        backgroundColor: AppColors.darkBgPrimary,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_showOnboarding) {
      return OnboardingTutorialScreen(
        onComplete: () => setState(() => _showOnboarding = false),
      );
    }
    if (_profile == null) {
      return ProfileSetupScreen(
        onComplete: (_) =>
            setState(() => _profile = MockData.athleteProfile),
      );
    }
    return MainNavShell(
      profile: _profile!,
      onProfileUpdated: (p) => setState(() => _profile = p),
    );
  }
}
