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

/// Heavy services (BLE, notifications, foreground task) are skipped under
/// [FeatureFlags.prototypeMode] — they pull in platform plugins that don't
/// run on web and would block the client demo.
Future<void> _initHeavyServices() async {
  if (FeatureFlags.prototypeMode) return;
  if (kIsWeb) return;
  // Real init lives in services/ — kept out of the demo entrypoint so the
  // prototype loads in Chrome with zero plugin friction.
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

// ──────────────────────────────────────────────────────────────
// PROTOTYPE FLOW — for client demos.
// Splash → RoleSelect → Login → MainNavShell (with mock profile)
// ──────────────────────────────────────────────────────────────
class _PrototypeFlow extends StatefulWidget {
  const _PrototypeFlow();

  @override
  State<_PrototypeFlow> createState() => _PrototypeFlowState();
}

enum _PrototypeStep { splash, roleSelect, login, register, home }

class _PrototypeFlowState extends State<_PrototypeFlow> {
  _PrototypeStep _step = _PrototypeStep.splash;
  UserRole _role = UserRole.athlete;

  UserProfile get _profile => _role == UserRole.trainer
      ? MockData.trainerProfile
      : MockData.athleteProfile;

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _PrototypeStep.splash:
        return SplashScreen(
          onDone: () =>
              setState(() => _step = _PrototypeStep.roleSelect),
        );
      case _PrototypeStep.roleSelect:
        return RoleSelectScreen(
          onSelected: (role) {
            setState(() {
              _role = role;
              _step = _PrototypeStep.login;
            });
          },
        );
      case _PrototypeStep.login:
        return LoginScreen(
          onSignedIn: () => setState(() => _step = _PrototypeStep.home),
          onCreateAccount: () => setState(() => _step = _PrototypeStep.register),
        );
      case _PrototypeStep.register:
        return RegisterScreen(
          onRegistered: () => setState(() => _step = _PrototypeStep.home),
          onBackToLogin: () => setState(() => _step = _PrototypeStep.login),
        );
      case _PrototypeStep.home:
        return MainNavShell(profile: _profile);
    }
  }
}

// ──────────────────────────────────────────────────────────────
// PRODUCTION FLOW — the legacy onboarding → profile setup → app flow.
// Used when FeatureFlags.prototypeMode is false (i.e. on-device builds).
// ──────────────────────────────────────────────────────────────
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
    // Storage is omitted from the demo build — keep this minimal and skip
    // real init so the app can still launch in any environment.
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
        onComplete: () => setState(() => _profile = MockData.athleteProfile),
      );
    }
    return MainNavShell(
      profile: _profile!,
      onProfileUpdated: (p) => setState(() => _profile = p),
    );
  }
}
