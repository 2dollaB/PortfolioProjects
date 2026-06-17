import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/strings.dart';
import '../config/theme.dart';

/// 8.4 — HRV Display widget
/// Calculates and displays RMSSD from RR intervals
class HrvChart extends StatelessWidget {
  final List<int> rrIntervals; // in milliseconds
  const HrvChart({super.key, required this.rrIntervals});

  /// Calculate RMSSD (Root Mean Square of Successive Differences)
  double get rmssd {
    if (rrIntervals.length < 2) return 0;
    double sumSquares = 0;
    int count = 0;
    for (int i = 1; i < rrIntervals.length; i++) {
      final diff = (rrIntervals[i] - rrIntervals[i - 1]).toDouble();
      // Filter out artifacts (diffs > 300ms are likely noise)
      if (diff.abs() < 300) {
        sumSquares += diff * diff;
        count++;
      }
    }
    if (count == 0) return 0;
    return math.sqrt(sumSquares / count);
  }

  /// SDNN (Standard Deviation of NN intervals)
  double get sdnn {
    if (rrIntervals.length < 2) return 0;
    final filtered = rrIntervals.where((rr) => rr > 300 && rr < 2000).toList();
    if (filtered.length < 2) return 0;
    final mean = filtered.reduce((a, b) => a + b) / filtered.length;
    final variance = filtered.fold<double>(
        0, (sum, rr) => sum + (rr - mean) * (rr - mean)) / filtered.length;
    return math.sqrt(variance);
  }

  String _hrvStatus(double rmssd) => Strings.hrvQuality(rmssd.round());

  Color _hrvColor(double rmssd) {
    if (rmssd <= 0) return AppTheme.textMuted;
    if (rmssd < 20) return const Color(0xFFEF4444);
    if (rmssd < 50) return const Color(0xFFF97316);
    if (rmssd < 100) return const Color(0xFF22C55E);
    return const Color(0xFF06B6D4);
  }

  @override
  Widget build(BuildContext context) {
    final r = rmssd;
    final s = sdnn;
    final color = _hrvColor(r);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RMSSD',
                    style: AppTheme.mono(fontSize: 9, letterSpacing: 1, color: AppTheme.textMuted)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(r > 0 ? r.toStringAsFixed(1) : '--',
                        style: AppTheme.heading(fontSize: 28, color: color)),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('ms', style: AppTheme.body(fontSize: 12, color: AppTheme.textMuted)),
                    ),
                  ],
                ),
                Text(_hrvStatus(r),
                    style: AppTheme.body(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('SDNN',
                    style: AppTheme.mono(fontSize: 9, letterSpacing: 1, color: AppTheme.textMuted)),
                Text(s > 0 ? '${s.toStringAsFixed(1)} ms' : '--',
                    style: AppTheme.heading(fontSize: 16, color: AppTheme.textSecondary)),
              ],
            ),
          ],
        ),
        if (rrIntervals.length >= 10) ...[
          const SizedBox(height: 12),
          // Mini RR interval scatter
          SizedBox(
            height: 60,
            child: CustomPaint(
              size: Size.infinite,
              painter: _RrScatterPainter(rrIntervals, color),
            ),
          ),
        ],
      ],
    );
  }
}

class _RrScatterPainter extends CustomPainter {
  final List<int> rr;
  final Color color;
  _RrScatterPainter(this.rr, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (rr.length < 2) return;
    // Show last 100 points max
    final points = rr.length > 100 ? rr.sublist(rr.length - 100) : rr;
    final filtered = points.where((v) => v > 300 && v < 2000).toList();
    if (filtered.isEmpty) return;

    final minRR = filtered.reduce(math.min).toDouble();
    final maxRR = filtered.reduce(math.max).toDouble();
    final range = maxRR - minRR;
    if (range <= 0) return;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.fill;

    for (int i = 0; i < filtered.length; i++) {
      final x = i / (filtered.length - 1) * size.width;
      final y = size.height - ((filtered[i] - minRR) / range * size.height);
      canvas.drawCircle(Offset(x, y), 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
