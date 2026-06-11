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
///
/// **Each tab has its own nested [Navigator]**, so routes pushed from
/// within a tab (settings, all-sessions, member-detail, session-detail,
/// edit-profile, etc.) stay inside that tab's stack — the bottom nav
/// stays visible across pushes. Industry-standard pattern.
class MainNavShell extends StatefulWidget {
  final UserProfile profile;
  final void Function(UserProfile)? onProfileUpdated;

  /// Sign-out callback bubbled up to the prototype flow.
  /// When invoked, the parent unmounts this shell and routes to login.
  final VoidCallback? onSignOut;

  /// Production-only: enables the athlete "Join a studio" CTA on home.
  final bool enableStudioJoin;

  const MainNavShell({
    super.key,
    required this.profile,
    this.onProfileUpdated,
    this.onSignOut,
    this.enableStudioJoin = false,
  });

  @override
  State<MainNavShell> createState() => _MainNavShellState();
}

class _MainNavShellState extends State<MainNavShell> {
  int _index = 0;
  late final List<GlobalKey<NavigatorState>> _navKeys;

  bool get _isTrainer => widget.profile.role == UserRole.trainer;

  @override
  void initState() {
    super.initState();
    final tabCount = _isTrainer ? 4 : 3;
    _navKeys = List.generate(tabCount, (_) => GlobalKey<NavigatorState>());
  }

  /// Tab root screens. Re-built each frame so they reflect any prop changes.
  /// MobileFrame is applied at the individual screen level (so pushed routes
  /// outside a tab's stack also get desktop centering). TV stays full-bleed.
  List<Widget> _tabRoots() {
    return _isTrainer
        ? [
            TrainerHomeScreen(
              profile: widget.profile,
              onSignOut: widget.onSignOut,
            ),
            const MemberListScreen(),
            const StudioAnalyticsScreen(),
            const TvHostScreen(),
          ]
        : [
            HomeScreen(
              profile: widget.profile,
              onProfileUpdated: widget.onProfileUpdated,
              onSignOut: widget.onSignOut,
              enableStudioJoin: widget.enableStudioJoin,
            ),
            const WorkoutHistoryScreen(),
            SettingsScreen(
              profile: widget.profile,
              onSignOut: widget.onSignOut,
            ),
          ];
  }

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

  Future<bool> _onWillPop() async {
    // If the current tab's nested navigator can pop, pop it instead of
    // popping the whole shell.
    final navState = _navKeys[_index].currentState;
    if (navState?.canPop() ?? false) {
      navState!.pop();
      return false;
    }
    return true;
  }

  void _onTabTap(int newIndex) {
    if (_index == newIndex) {
      // Tapping the active tab pops to its root — Material standard behavior.
      _navKeys[_index].currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() => _index = newIndex);
  }

  @override
  Widget build(BuildContext context) {
    final roots = _tabRoots();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _onWillPop();
      },
      child: Scaffold(
        backgroundColor: AppColors.darkBgPrimary,
        body: IndexedStack(
          index: _index,
          children: [
            for (int i = 0; i < roots.length; i++)
              Navigator(
                key: _navKeys[i],
                onGenerateRoute: (settings) => MaterialPageRoute(
                  settings: settings,
                  builder: (_) => roots[i],
                ),
              ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.darkBorder)),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _onTabTap,
            destinations: _tabs,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          ),
        ),
      ),
    );
  }
}
