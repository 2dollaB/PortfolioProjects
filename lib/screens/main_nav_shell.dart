import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/user_profile.dart';
import 'home_screen.dart';
import 'workout_history_screen.dart';
import 'settings_screen.dart';
import 'trainer_home_screen.dart';
import 'member_list_screen.dart';
import 'studio_analytics_screen.dart';
import 'tv_host_screen.dart';

/// Role-aware bottom nav shell.
/// Athlete tabs: Home · History · Profile
/// Trainer tabs: Home · Members · Analytics · TV
class MainNavShell extends StatefulWidget {
  final UserProfile profile;
  final void Function(UserProfile)? onProfileUpdated;

  const MainNavShell({
    super.key,
    required this.profile,
    this.onProfileUpdated,
  });

  @override
  State<MainNavShell> createState() => _MainNavShellState();
}

class _MainNavShellState extends State<MainNavShell> {
  int _index = 0;

  bool get _isTrainer => widget.profile.role == UserRole.trainer;

  List<Widget> get _screens => _isTrainer
      ? [
          TrainerHomeScreen(profile: widget.profile),
          const MemberListScreen(),
          const StudioAnalyticsScreen(),
          const TvHostScreen(),
        ]
      : [
          HomeScreen(
            profile: widget.profile,
            onProfileUpdated: widget.onProfileUpdated,
          ),
          const WorkoutHistoryScreen(),
          SettingsScreen(profile: widget.profile),
        ];

  List<NavigationDestination> get _tabs => _isTrainer
      ? const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded),
            label: 'Members',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.tv_outlined),
            selectedIcon: Icon(Icons.tv_rounded),
            label: 'TV',
          ),
        ]
      : const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBgPrimary,
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.darkBorder)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: _tabs,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      ),
    );
  }
}
