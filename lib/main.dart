import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/theme.dart';
import 'providers/providers.dart';
import 'repositories/user_repository.dart';
import 'repositories/workout_repository.dart';
import 'screens/login_screen.dart';
import 'screens/main_nav_shell.dart';
import 'screens/onboarding_tutorial_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'services/ble_hr_service.dart';
import 'services/foreground_service.dart';
import 'services/migration_service.dart';
import 'services/notification_service.dart';
import 'services/unit_preference.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase init
  await Firebase.initializeApp();

  // BLE + services init
  await initBle();
  initForegroundTask();
  await NotificationService.init();
  await UnitPreference.load();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.background,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const ProviderScope(child: BeatSyncApp()));
}

class BeatSyncApp extends ConsumerStatefulWidget {
  const BeatSyncApp({super.key});

  @override
  ConsumerState<BeatSyncApp> createState() => _BeatSyncAppState();
}

class _BeatSyncAppState extends ConsumerState<BeatSyncApp> {
  @override
  void initState() {
    super.initState();
    // Load saved theme
    ref.read(themeModeProvider.notifier).loadSaved();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'BeatSync',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const _AuthGate(),
    );
  }
}

/// Routes based on auth state:
/// Not logged in → LoginScreen
/// Logged in, no profile → ProfileSetupScreen
/// Logged in + profile → MainNavShell
class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  bool _migrationDone = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const LoginScreen(),
      data: (user) {
        if (user == null) return const LoginScreen();

        // Trigger migration on first authenticated build
        if (!_migrationDone) {
          _migrationDone = true;
          _runMigration(user.uid);
        }

        return const _ProfileGate();
      },
    );
  }

  Future<void> _runMigration(String uid) async {
    final userRepo = ref.read(userRepositoryProvider);
    final workoutRepo = ref.read(workoutRepositoryProvider);
    final migration = MigrationService(userRepo, workoutRepo);
    await migration.migrateIfNeeded(uid);
  }
}

/// Once authenticated, check if profile exists
class _ProfileGate extends ConsumerStatefulWidget {
  const _ProfileGate();

  @override
  ConsumerState<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends ConsumerState<_ProfileGate> {
  bool _showOnboarding = false;
  bool _checkedOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final should = await OnboardingTutorialScreen.shouldShow();
    if (mounted) setState(() {
      _showOnboarding = should;
      _checkedOnboarding = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    if (!_checkedOnboarding) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_showOnboarding) {
      return OnboardingTutorialScreen(
        onComplete: () => setState(() => _showOnboarding = false),
      );
    }

    return profileAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => ProfileSetupScreen(
        onComplete: () => ref.invalidate(profileProvider),
      ),
      data: (profile) {
        if (profile == null) {
          return ProfileSetupScreen(
            onComplete: () => ref.invalidate(profileProvider),
          );
        }
        return MainNavShell(
          profile: profile,
          onProfileUpdated: (p) async {
            await ref.read(profileProvider.notifier).updateProfile(p);
          },
        );
      },
    );
  }
}
