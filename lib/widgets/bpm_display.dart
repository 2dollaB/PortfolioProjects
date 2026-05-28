import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/hr_zones.dart';
import '../config/theme.dart';

/// Massive BPM number with a circular HR% ring around it.
/// Ring color follows the live HR zone. Number pulses subtly with each beat.
class BpmDisplay extends StatefulWidget {
  /// Live BPM. Null → shows "--".
  final int? bpm;

  /// Max HR for ring %. If 0/null, ring fills proportional to bpm/220.
  final int hrMax;

  /// Diameter of the ring. Number scales to fit.
  final double size;

  /// Show the live pulse animation (scale 1.0 → 1.02 → 1.0). False for static displays.
  final bool pulse;

  const BpmDisplay({
    super.key,
    required this.bpm,
    required this.hrMax,
    this.size = 240,
    this.pulse = true,
  });

  @override
  State<BpmDisplay> createState() => _BpmDisplayState();
}

class _BpmDisplayState extends State<BpmDisplay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;

  Duration _periodFor(int? bpm) {
    final b = (bpm ?? 60).clamp(30, 220);
    return Duration(milliseconds: (60000 / b).round());
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: _periodFor(widget.bpm),
    );
    _pulseAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.025)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.025, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 65,
      ),
    ]).animate(_pulseController);

    if (widget.pulse && widget.bpm != null) _pulseController.repeat();
  }

  @override
  void didUpdateWidget(covariant BpmDisplay old) {
    super.didUpdateWidget(old);
    if (old.bpm != widget.bpm) {
      _pulseController.duration = _periodFor(widget.bpm);
    }
    final shouldRun = widget.pulse && widget.bpm != null;
    if (shouldRun && !_pulseController.isAnimating) {
      _pulseController.repeat();
    } else if (!shouldRun && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bpm = widget.bpm;
    final zone = bpm != null ? HrZones.fromBpm(bpm, widget.hrMax) : 0;
    final pct = bpm != null && widget.hrMax > 0
        ? (bpm / widget.hrMax).clamp(0.0, 1.0)
        : 0.0;
    final color = AppColors.zoneColor(zone == 0 ? 1 : zone);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ring
          SizedBox.expand(
            child: CustomPaint(
              painter: _RingPainter(
                progress: pct,
                color: color,
                trackColor: AppColors.darkBorder,
                strokeWidth: 10,
              ),
            ),
          ),
          // Number
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, _) {
              return Transform.scale(
                scale: _pulseAnim.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      bpm?.toString() ?? '--',
                      style: AppTheme.displayXL(
                        color: AppColors.darkTextPrimary,
                        glow: color,
                      ).copyWith(fontSize: widget.size * 0.32),
                    ),
                    const SizedBox(height: AppSpacing.micro),
                    Text(
                      'BPM',
                      style: AppTheme.micro().copyWith(letterSpacing: 2),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        bpm != null && widget.hrMax > 0
                            ? '${(pct * 100).round()}% HRmax'
                            : 'Standby',
                        style: AppTheme.caption(color: color).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;

    final track = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);

    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        rect,
        -math.pi / 2, // start at 12 o'clock
        2 * math.pi * progress,
        false,
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}
