import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
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
import 'services/auth_service.dart';
import 'services/ble_hr_service.dart';
import 'services/foreground_service.dart';
import 'services/mock_data.dart';
import 'services/studio_repository.dart';
import 'services/user_repository.dart';

Future<void> _initHeavyServices() async {
  if (FeatureFlags.prototypeMode) return;
  if (kIsWeb) return;
  // Kept out of the demo entrypoint so the prototype loads in any browser
  // with zero friction.
  await initBle();
  initForegroundTask();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
// PRODUCTION FLOW — AuthGate (active when FeatureFlags.prototypeMode is false)
//
//   authStateChanges:
//     signed-out                → _AuthFlow (login ⇄ register)
//     signed-in, no profile doc → _ProfileOnboarding (role → wizard → persist)
//     signed-in + profile doc   → MainNavShell
//
// No screen drives navigation manually: Firebase auth state and the
// users/{uid} snapshot stream decide what's shown.
// ──────────────────────────────────────────────────────────────────────
class _ProductionFlow extends StatelessWidget {
  const _ProductionFlow();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingScaffold();
        }
        final user = snap.data;
        if (user == null) return const _AuthFlow();
        return _ProfileGate(uid: user.uid);
      },
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: AppColors.darkBgPrimary,
        body: Center(child: CircularProgressIndicator()),
      );
}

/// Login ⇄ register toggle for signed-out users.
class _AuthFlow extends StatefulWidget {
  const _AuthFlow();

  @override
  State<_AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<_AuthFlow> {
  bool _showRegister = false;

  @override
  Widget build(BuildContext context) {
    if (_showRegister) {
      return RegisterScreen(
        onRegistered: (_) {},
        onBackToLogin: () => setState(() => _showRegister = false),
        register: AuthService.register,
      );
    }
    return LoginScreen(
      onSignedIn: (_) {},
      onCreateAccount: () => setState(() => _showRegister = true),
      authenticate: AuthService.signIn,
    );
  }
}

/// Loads the signed-in user's profile doc; routes to onboarding or home.
class _ProfileGate extends StatelessWidget {
  final String uid;
  const _ProfileGate({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: UserRepository.watch(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _LoadingScaffold();
        }
        final profile = snap.data;
        if (profile == null) return _ProfileOnboarding(uid: uid);
        return MainNavShell(
          profile: profile,
          onSignOut: () => AuthService.signOut(),
          enableStudioJoin: true,
        );
      },
    );
  }
}

/// Role select → profile-setup wizard → write users/{uid} (+ studio for
/// trainers). On success the profile stream emits and _ProfileGate swaps in
/// MainNavShell — no manual navigation here.
class _ProfileOnboarding extends StatefulWidget {
  final String uid;
  const _ProfileOnboarding({required this.uid});

  @override
  State<_ProfileOnboarding> createState() => _ProfileOnboardingState();
}

class _ProfileOnboardingState extends State<_ProfileOnboarding> {
  UserRole? _role;

  Future<void> _persist(ProfileSetupResult result) async {
    final uid = widget.uid;
    final email = AuthService.currentUser?.email ?? '';
    if (result.profile.role == UserRole.trainer) {
      final studioId = await StudioRepository.create(
        ownerUid: uid,
        name: result.studioName.isEmpty ? 'My Studio' : result.studioName,
        location:
            result.studioLocation.isEmpty ? null : result.studioLocation,
        maxMembers: result.studioCapacity,
        inviteCode: result.inviteCode,
      );
      await UserRepository.create(
        uid,
        result.profile.copyWith(id: uid, email: email, studioId: studioId),
      );
    } else {
      await UserRepository.create(
        uid,
        result.profile.copyWith(id: uid, email: email),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_role == null) {
      return RoleSelectScreen(
        onSelected: (r) => setState(() => _role = r),
      );
    }
    return ProfileSetupScreen(
      role: _role!,
      initialName: AuthService.currentUser?.displayName,
      onComplete: (_) {},
      onSave: _persist,
    );
  }
}
