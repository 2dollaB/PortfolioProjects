import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';

/// 9.1 — Onboarding Tutorial Carousel
/// Shown once on first launch to introduce key features
class OnboardingTutorialScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingTutorialScreen({super.key, required this.onComplete});

  static const _seenKey = 'onboarding_seen';

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_seenKey) ?? false);
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }

  @override
  State<OnboardingTutorialScreen> createState() => _OnboardingTutorialScreenState();
}

class _OnboardingTutorialScreenState extends State<OnboardingTutorialScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _slides = [
    _Slide(
      icon: Icons.favorite_rounded,
      color: Color(0xFFEF4444),
      title: 'Real-Time Heart Rate',
      body: 'Connect any Bluetooth heart rate monitor and see your BPM, zone, and live chart during workouts.',
    ),
    _Slide(
      icon: Icons.bar_chart_rounded,
      color: Color(0xFF8B5CF6),
      title: '5 Training Zones',
      body: 'From recovery to maximum effort — each zone is color-coded so you always know your intensity.',
    ),
    _Slide(
      icon: Icons.timeline_rounded,
      color: Color(0xFF06B6D4),
      title: 'TRIMP & Training Effect',
      body: 'Advanced analytics measure your workout load and physiological impact — like a personal sports scientist.',
    ),
    _Slide(
      icon: Icons.groups_rounded,
      color: Color(0xFF22C55E),
      title: 'Group Sessions',
      body: 'Trainers can host live sessions with a TV dashboard. Athletes join and their HR data streams in real-time.',
    ),
    _Slide(
      icon: Icons.trending_up_rounded,
      color: Color(0xFFF97316),
      title: 'Trends & Recovery',
      body: 'Track your training load over weeks, monitor HRV, and optimize your recovery for peak performance.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    OnboardingTutorialScreen.markSeen();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: Text('Skip',
                    style: AppTheme.body(color: AppTheme.textMuted, fontSize: 14)),
              ),
            ),
            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, i) {
                  final slide = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120, height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                slide.color.withValues(alpha: 0.2),
                                slide.color.withValues(alpha: 0.05),
                              ],
                            ),
                          ),
                          child: Icon(slide.icon, size: 56, color: slide.color),
                        ),
                        const SizedBox(height: 32),
                        Text(slide.title,
                            style: AppTheme.heading(fontSize: 24),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        Text(slide.body,
                            style: AppTheme.body(fontSize: 15, color: AppTheme.textSecondary),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Dots + button
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  // Page dots
                  Row(
                    children: List.generate(_slides.length, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 6),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? _slides[_currentPage].color
                              : AppTheme.surface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  // Next / Get Started button
                  GestureDetector(
                    onTap: _currentPage == _slides.length - 1
                        ? _finish
                        : () => _controller.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.accent, AppTheme.accentDark],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _currentPage == _slides.length - 1 ? 'Get Started' : 'Next',
                        style: AppTheme.body(
                          fontSize: 14, color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _Slide({required this.icon, required this.color, required this.title, required this.body});
}
