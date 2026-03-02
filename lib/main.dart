import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config/theme.dart';
import 'models/user_profile.dart';
import 'screens/home_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'services/ble_hr_service.dart';
import 'services/foreground_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize BLE
  await initBle();

  // Initialize foreground task for background workout tracking
  initForegroundTask();

  // Lock to portrait mode
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Set status bar style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.background,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Check if profile exists
  final profile = await StorageService.loadProfile();

  runApp(BeatSyncApp(initialProfile: profile));
}

class BeatSyncApp extends StatefulWidget {
  final UserProfile? initialProfile;

  const BeatSyncApp({super.key, this.initialProfile});

  @override
  State<BeatSyncApp> createState() => _BeatSyncAppState();
}

class _BeatSyncAppState extends State<BeatSyncApp> {
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
  }

  void _onProfileComplete() async {
    final profile = await StorageService.loadProfile();
    setState(() => _profile = profile);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BeatSync',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: _profile == null
          ? ProfileSetupScreen(onComplete: _onProfileComplete)
          : HomeScreen(
              profile: _profile!,
              onProfileUpdated: (p) => setState(() => _profile = p),
            ),
    );
  }
}
