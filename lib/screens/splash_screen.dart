import 'package:flutter/material.dart';
import '../widgets/mobile_frame.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../widgets/logo_heartbeat.dart';

/// First screen the user sees while the app warms up.
/// Brand-red heartbeat against a near-black background, then fades out
/// to whatever [onReady] navigates to.
class SplashScreen extends StatefulWidget {
  /// Async work to perform during the splash (cache warm-up, auth check, etc.).
  /// Optional â€” pass null for a pure timed splash.
  final Future<void> Function()? onReady;

  /// Called after both [onReady] completes AND [minimumDwell] has elapsed
  /// AND the fade-out has finished. Use this to navigate to the next screen.
  final VoidCallback? onDone;

  final Duration minimumDwell;

  const SplashScreen({
    super.key,
    this.onReady,
    this.onDone,
    this.minimumDwell = const Duration(milliseconds: 1600),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  bool _fading = false;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );
    _run();
  }

  Future<void> _run() async {
    await Future.wait([
      Future.delayed(widget.minimumDwell),
      widget.onReady?.call() ?? Future.value(),
    ]);
    if (!mounted) return;
    setState(() => _fading = true);
    await _fade.reverse();
    if (!mounted) return;
    widget.onDone?.call();
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
      backgroundColor: AppColors.darkBgPrimary,
      body: FadeTransition(
        opacity: _fade,
        child: Stack(
          children: [
            // Subtle radial vignette
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.9,
                    colors: [
                      AppColors.brandRed.withValues(alpha: 0.10),
                      AppColors.darkBgPrimary,
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const LogoHeartbeat(size: 80, showWordmark: true),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'TRAIN TOGETHER',
                    style: AppTheme.micro(
                      color: AppColors.darkTextSecondary,
                    ).copyWith(letterSpacing: 4),
                  ),
                ],
              ),
            ),
            if (_fading) const SizedBox.shrink(),
          ],
        ),
      ),
      ),
    );
  }
}