import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/theme.dart';
import 'models/user_profile.dart';
import 'screens/main_nav_shell.dart';
import 'screens/onboarding_tutorial_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'services/ble_hr_service.dart';
import 'services/foreground_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/unit_preference.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  final profile = await StorageService.loadProfile();
  final showOnboarding = await OnboardingTutorialScreen.shouldShow();

  // 9.4 — Load saved theme mode
  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString('theme_mode') ?? 'dark';
  final themeMode = savedTheme == 'light' ? ThemeMode.light
      : savedTheme == 'system' ? ThemeMode.system
      : ThemeMode.dark;

  runApp(BeatSyncApp(
    initialProfile: profile,
    showOnboarding: showOnboarding,
    initialThemeMode: themeMode,
  ));
}

class BeatSyncApp extends StatefulWidget {
  final UserProfile? initialProfile;
  final bool showOnboarding;
  final ThemeMode initialThemeMode;

  const BeatSyncApp({
    super.key,
    this.initialProfile,
    this.showOnboarding = false,
    this.initialThemeMode = ThemeMode.dark,
  });

  /// Global key for theme switching from settings
  static final GlobalKey<BeatSyncAppState> appKey = GlobalKey<BeatSyncAppState>();

  @override
  State<BeatSyncApp> createState() => BeatSyncAppState();
}

class BeatSyncAppState extends State<BeatSyncApp> {
  UserProfile? _profile;
  late bool _showOnboarding;
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
    _showOnboarding = widget.showOnboarding;
    _themeMode = widget.initialThemeMode;
  }

  void _onProfileComplete() async {
    final profile = await StorageService.loadProfile();
    setState(() => _profile = profile);
  }

  /// 9.4 — Called from settings to toggle theme
  void setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    final key = mode == ThemeMode.light ? 'light'
        : mode == ThemeMode.system ? 'system' : 'dark';
    await prefs.setString('theme_mode', key);
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
      home: _showOnboarding
          ? OnboardingTutorialScreen(
              onComplete: () => setState(() => _showOnboarding = false))
          : _profile == null
              ? ProfileSetupScreen(onComplete: _onProfileComplete)
              : MainNavShell(
                  profile: _profile!,
                  onProfileUpdated: (p) => setState(() => _profile = p),
                ),
    );
  }
}
