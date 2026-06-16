import 'package:flutter/material.dart';
import '../widgets/mobile_frame.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../widgets/beat_button.dart';
import '../widgets/logo_heartbeat.dart';

/// Two-slide tutorial shown on first launch. Has a Skip in the top-right
/// for users who already know the app.
class OnboardingTutorialScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingTutorialScreen({super.key, required this.onComplete});

  static const _seenKey = 'onboarding_seen';

  static Future<bool> shouldShow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(_seenKey) ?? false);
    } catch (_) {
      // Prototype/web â€” no persistence. Always show.
      return true;
    }
  }

  static Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_seenKey, true);
    } catch (_) {/* prototype â€” ignore */}
  }

  @override
  State<OnboardingTutorialScreen> createState() =>
      _OnboardingTutorialScreenState();
}

class _OnboardingTutorialScreenState extends State<OnboardingTutorialScreen> {
  final _controller = PageController();
  int _page = 0;

  List<_Slide> get _slides => [
        _Slide(
          icon: Icons.bluetooth_searching_rounded,
          title: Strings.onbConnectTitle,
          body: Strings.onbConnectBody,
        ),
        _Slide(
          icon: Icons.favorite_rounded,
          title: Strings.onbNotCompTitle,
          body: Strings.onbNotCompBody,
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

  void _next() {
    if (_page == _slides.length - 1) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: logo + skip
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.md, 0,
              ),
              child: Row(
                children: [
                  const LogoHeartbeat(size: 24, showWordmark: true),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: Text(Strings.skip),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            // Dots + next/get-started
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.lg,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.brandRed
                              : AppColors.bgTertiary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  BeatPrimaryButton(
                    label: _page == _slides.length - 1
                        ? Strings.getStarted
                        : Strings.next,
                    icon: _page == _slides.length - 1
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                    onPressed: _next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _Slide {
  final IconData icon;
  final String title;
  final String body;
  const _Slide({
    required this.icon,
    required this.title,
    required this.body,
  });
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon plate
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.brandRed.withValues(alpha: 0.25),
                  AppColors.brandRed.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.bgSecondary,
                  border: Border.all(
                    color: AppColors.brandRed.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Icon(slide.icon, color: AppColors.brandRed, size: 44),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            slide.title,
            style: AppTheme.h1().copyWith(fontSize: 30),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            slide.body,
            style: AppTheme.bodyLarge(color: AppColors.textSecondary)
                .copyWith(height: 1.55),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}