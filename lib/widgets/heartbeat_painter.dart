import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Scrolling ECG waveform — one heartbeat repeats every `beatPeriod`,
/// shape: flat baseline → sharp upward QRS spike → brief negative deflection
/// → gentle T-wave → flat baseline. Scrolls left as `phase` advances.
///
/// Use inside an [AnimatedBuilder] driven by an [AnimationController] whose
/// duration is one full beat (see [ScrollingEcg] below for the wrapper).
class HeartbeatPainter extends CustomPainter {
  /// 0.0 → 1.0 within one beat cycle. Animate this externally.
  final double phase;

  /// Waveform color.
  final Color color;

  /// Line stroke width.
  final double strokeWidth;

  /// How many beats are visible horizontally at once. Higher = denser line.
  final double beatsPerWidth;

  HeartbeatPainter({
    required this.phase,
    required this.color,
    this.strokeWidth = 1.5,
    this.beatsPerWidth = 2.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final h = size.height;
    final w = size.width;
    final baseline = h * 0.55;

    // Each beat spans w / beatsPerWidth in horizontal pixels.
    final beatWidth = w / beatsPerWidth;

    // Sample resolution.
    const samples = 240;

    bool started = false;
    for (int i = 0; i <= samples; i++) {
      final x = (i / samples) * w;
      // Position inside the current beat, shifted by phase to make it scroll.
      // The waveform moves right→left, so subtract phase.
      final beatPos = ((x / beatWidth) - phase) % 1.0;
      final y = baseline - _ecgWave(beatPos) * h * 0.42;

      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  /// ECG waveform sampled within [0, 1]: P → QRS → T → baseline.
  /// Returns amplitude in roughly [-0.3, 1.0].
  static double _ecgWave(double t) {
    // P wave: small bump at t≈0.08
    final p = _gaussian(t, center: 0.08, width: 0.025, amp: 0.15);
    // Q dip: small downward at t≈0.18
    final q = _gaussian(t, center: 0.18, width: 0.012, amp: -0.18);
    // R spike: sharp upward peak at t≈0.22 (the dominant feature)
    final r = _gaussian(t, center: 0.22, width: 0.013, amp: 1.0);
    // S dip: brief downward after R at t≈0.27
    final s = _gaussian(t, center: 0.27, width: 0.014, amp: -0.28);
    // T wave: gentle hump at t≈0.45
    final tw = _gaussian(t, center: 0.45, width: 0.05, amp: 0.28);
    return p + q + r + s + tw;
  }

  static double _gaussian(double x,
      {required double center, required double width, required double amp}) {
    final d = (x - center) / width;
    return amp * math.exp(-0.5 * d * d);
  }

  @override
  bool shouldRepaint(covariant HeartbeatPainter old) =>
      old.phase != phase || old.color != color || old.strokeWidth != strokeWidth;
}

/// Convenience widget: scrolling ECG line whose scroll speed scales with BPM.
/// At higher BPM the wave scrolls faster — exactly as if you're watching
/// a live patient monitor.
class ScrollingEcg extends StatefulWidget {
  /// Live BPM. Drives scroll speed (one beat-cycle takes 60/bpm seconds).
  final int bpm;
  final Color color;
  final double strokeWidth;
  final double beatsPerWidth;

  const ScrollingEcg({
    super.key,
    required this.bpm,
    required this.color,
    this.strokeWidth = 1.5,
    this.beatsPerWidth = 2.5,
  });

  @override
  State<ScrollingEcg> createState() => _ScrollingEcgState();
}

class _ScrollingEcgState extends State<ScrollingEcg>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  Duration _periodForBpm(int bpm) {
    // One full beat = 60 / bpm seconds. Clamp to avoid div-by-zero / silliness.
    final safeBpm = bpm.clamp(30, 220);
    return Duration(milliseconds: (60000 / safeBpm).round());
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _periodForBpm(widget.bpm),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant ScrollingEcg old) {
    super.didUpdateWidget(old);
    if (old.bpm != widget.bpm) {
      _controller.duration = _periodForBpm(widget.bpm);
      if (!_controller.isAnimating) _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: HeartbeatPainter(
            phase: _controller.value,
            color: widget.color,
            strokeWidth: widget.strokeWidth,
            beatsPerWidth: widget.beatsPerWidth,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}
