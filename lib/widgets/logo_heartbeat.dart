import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/theme.dart';

/// BeatSync animated logo — pulsing heart icon + brand-red glow + optional wordmark.
///
/// Beat rhythm: scale 1.0 → 1.12 → 1.0 over ~300ms ease-in-out,
/// followed by a ~700ms pause. Simulates a resting ~60 BPM heart.
/// The brand-red glow expands and fades in sync with the scale.
///
/// Used on: splash, app bar, loading states, empty states.
class LogoHeartbeat extends StatefulWidget {
  /// Size of the heart icon (the wordmark scales beside it).
  final double size;

  /// Whether to render the "BeatSync" wordmark next to the heart.
  final bool showWordmark;

  /// Override the heart + glow color. Defaults to brand red.
  final Color color;

  /// Whether the heartbeat is animating. False = static icon (e.g. when paused).
  final bool animate;

  const LogoHeartbeat({
    super.key,
    this.size = 48,
    this.showWordmark = true,
    this.color = AppColors.brandRed,
    this.animate = true,
  });

  @override
  State<LogoHeartbeat> createState() => _LogoHeartbeatState();
}

class _LogoHeartbeatState extends State<LogoHeartbeat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _glow;

  static const _beatDuration = Duration(milliseconds: 300);
  static const _pauseDuration = Duration(milliseconds: 700);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _beatDuration + _pauseDuration,
    );

    // Scale: rest → up → rest during the beat window (~30% of cycle),
    // then hold flat for the rest (~70%). Simulates a ~60 BPM resting beat.
    final beatFraction =
        _beatDuration.inMilliseconds / (_beatDuration + _pauseDuration).inMilliseconds;

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: beatFraction * 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.12, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: beatFraction * 60,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: (1 - beatFraction) * 100),
    ]).animate(_controller);

    _glow = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.4)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: beatFraction * 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.4, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: beatFraction * 60,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0),
          weight: (1 - beatFraction) * 100),
    ]).animate(_controller);

    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant LogoHeartbeat old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heart = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glowAlpha = _glow.value;
        final scale = _scale.value;
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: glowAlpha > 0
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: glowAlpha),
                        blurRadius: widget.size * 0.5,
                        spreadRadius: widget.size * 0.05,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              Icons.favorite_rounded,
              color: widget.color,
              size: widget.size,
            ),
          ),
        );
      },
    );

    if (!widget.showWordmark) return heart;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        heart,
        SizedBox(width: widget.size * 0.25),
        Text(
          'BeatSync',
          style: AppTheme.h1().copyWith(
            fontSize: widget.size * 0.55,
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
