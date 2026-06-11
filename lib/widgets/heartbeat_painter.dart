import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Continuously-scrolling ECG with per-beat variation, slow baseline drift,
/// and high-frequency micro-noise — looks like a live patient monitor rather
/// than a repeating loop.
///
/// **Phase accumulator model.** Instead of computing beat index from
/// absolute time and BPM (which causes visible "snaps" whenever BPM changes
/// because beat positions retroactively shift), the widget integrates BPM
/// over time into a monotonically-increasing `phase`:
///
///   d(phase) / dt = bpm / 60
///
/// `phase` represents "total beats elapsed". A beat index is just
/// `floor(phase)`, fully decoupled from instantaneous BPM. The result is a
/// continuous, never-rewinding trace that smoothly speeds up / slows down
/// when BPM changes — never jumps.
///
/// **Per-card seed.** Each ScrollingEcg instance picks a random seed at mount.
/// All hash functions mix in the seed so different athletes get distinct
/// beat-to-beat variation patterns instead of all marching in lockstep.
class HeartbeatPainter extends CustomPainter {
  /// Total beats elapsed at the right edge of the screen ("now").
  final double phaseAtNow;

  /// Per-instance seed so cards desynchronize their variation patterns.
  final int seed;

  final Color color;
  final double strokeWidth;

  /// How wide one beat is on screen, in pixels. Independent of BPM — BPM
  /// affects how fast phase advances, which in turn advances how quickly
  /// content scrolls past at this fixed width.
  final double pixelsPerBeat;

  HeartbeatPainter({
    required this.phaseAtNow,
    required this.seed,
    required this.color,
    this.strokeWidth = 1.5,
    this.pixelsPerBeat = 80,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    final baseline = h * 0.55;
    final amp = h * 0.42;

    final path = Path();
    bool started = false;

    // Each x column shows the phase at (w - x) / pixelsPerBeat beats ago.
    // Rightmost column = phaseAtNow ("now"), leftmost = past.
    final endX = w.ceil();
    for (int x = 0; x <= endX; x++) {
      final phaseHere = phaseAtNow - (w - x) / pixelsPerBeat;
      if (phaseHere < 0) continue;

      final beatIndex = phaseHere.floor();
      final tInBeat = phaseHere - beatIndex;
      final y = baseline - _ecgSample(beatIndex, tInBeat, phaseHere) * amp;

      if (!started) {
        path.moveTo(x.toDouble(), y);
        started = true;
      } else {
        path.lineTo(x.toDouble(), y);
      }
    }
    canvas.drawPath(path, paint);
  }

  /// One ECG sample. [beatIndex] is the integer beat number, [tInBeat] is
  /// the fractional position within that beat (0..1), and [phase] is the
  /// absolute phase value (used by drift/noise so they're decoupled from
  /// per-beat resets).
  double _ecgSample(int beatIndex, double tInBeat, double phase) {
    // Five independent deterministic hashes for richer variation.
    final h1 = _hash(beatIndex);
    final h2 = _hash(beatIndex * 7 + 13);
    final h3 = _hash(beatIndex * 11 + 5);
    final h4 = _hash(beatIndex * 17 + 7);
    final h5 = _hash(beatIndex * 23 + 11);

    // Amplitude jitter ±15% per beat — visibly different heights.
    final ampJ = 0.85 + 0.30 * h1;
    // QRS centred at slightly different positions ±2% of beat width.
    final centerShift = (h2 - 0.5) * 0.04;
    // QRS width varies ±8% — some beats sharper, some softer.
    final widthJ = 0.92 + 0.16 * h3;
    // T wave amplitude varies a lot (real T waves are heart-mood-sensitive).
    final tAmpJ = 0.70 + 0.50 * h4;
    // Occasionally (1 in ~25 beats), throw in a slightly taller R spike —
    // looks like an occasional stronger beat. Subtle, not jarring.
    final isStronger = h5 < 0.04;
    final rMul = isStronger ? 1.35 : 1.0;

    // P-Q-R-S-T morphology — each is a Gaussian bump in time.
    final p = _gaussian(
        tInBeat, 0.08 + centerShift, 0.025 * widthJ, 0.15 * ampJ);
    final q = _gaussian(
        tInBeat, 0.18 + centerShift, 0.012 * widthJ, -0.18 * ampJ);
    final r = _gaussian(
        tInBeat, 0.22 + centerShift, 0.013 * widthJ, 1.0 * ampJ * rMul);
    final s = _gaussian(
        tInBeat, 0.27 + centerShift, 0.014 * widthJ, -0.28 * ampJ);
    final tw = _gaussian(
        tInBeat, 0.45 + centerShift, 0.05 * widthJ, 0.28 * tAmpJ);

    // Continuous noise components — driven by phase (monotonic) so they're
    // immune to BPM changes / beat realignment.
    final drift = _drift(phase);
    final noise = _noise(phase);

    return p + q + r + s + tw + drift + noise;
  }

  static double _gaussian(double x, double center, double width, double amp) {
    final d = (x - center) / width;
    return amp * math.exp(-0.5 * d * d);
  }

  /// Knuth multiplicative hash mixed with the per-instance seed.
  /// Returns a deterministic 0..1 value.
  double _hash(int n) {
    int h = ((n + seed) * 2654435761) & 0xFFFFFFFF;
    h = (h ^ (h >> 16)) & 0xFFFFFFFF;
    return h.toDouble() / 0xFFFFFFFF;
  }

  /// Slow baseline drift — looks like the subject is breathing.
  /// Two incommensurate slow sines so there's no visible repeat.
  static double _drift(double phase) {
    return 0.05 * math.sin(phase * 0.7) +
        0.03 * math.sin(phase * 1.3 + 1.7);
  }

  /// High-frequency micro-noise. Sum of incommensurate sines = smooth noise.
  static double _noise(double phase) {
    return 0.018 * math.sin(phase * 23.7) +
        0.012 * math.sin(phase * 41.3 + 1.7) +
        0.008 * math.sin(phase * 67.1 + 2.9);
  }

  @override
  bool shouldRepaint(covariant HeartbeatPainter old) =>
      old.phaseAtNow != phaseAtNow ||
      old.color != color ||
      old.seed != seed;
}

/// Live ECG widget — drives a phase accumulator each frame so the trace
/// flows smoothly regardless of BPM changes.
class ScrollingEcg extends StatefulWidget {
  final int bpm;
  final Color color;
  final double strokeWidth;
  final double pixelsPerBeat;

  /// Optional explicit seed for the variation pattern. When null, picks a
  /// random seed at mount so each card gets a unique rhythm.
  final int? seed;

  const ScrollingEcg({
    super.key,
    required this.bpm,
    required this.color,
    this.strokeWidth = 1.5,
    this.pixelsPerBeat = 80,
    this.seed,
  });

  @override
  State<ScrollingEcg> createState() => _ScrollingEcgState();
}

class _ScrollingEcgState extends State<ScrollingEcg>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final int _seed;
  double _phase = 0;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _seed = widget.seed ?? math.Random().nextInt(0xFFFFFFF);
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    // If the tab was backgrounded for a while, dt can be huge — don't try
    // to "catch up" with one giant phase jump. Just keep flowing.
    if (dt <= 0 || dt > 0.5) return;
    final bpm = widget.bpm.clamp(30, 220);
    setState(() {
      _phase += (bpm / 60) * dt;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: HeartbeatPainter(
        phaseAtNow: _phase,
        seed: _seed,
        color: widget.color,
        strokeWidth: widget.strokeWidth,
        pixelsPerBeat: widget.pixelsPerBeat,
      ),
      size: Size.infinite,
    );
  }
}
