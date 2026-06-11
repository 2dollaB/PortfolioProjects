import 'dart:math' as math;
import '../widgets/mobile_frame.dart';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../widgets/stat_chip.dart';

class StudioAnalyticsScreen extends StatelessWidget {
  const StudioAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
      backgroundColor: AppColors.darkBgPrimary,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl,
          ),
          children: [
            Text('Analytics', style: AppTheme.h1().copyWith(fontSize: 26)),
            const SizedBox(height: AppSpacing.xs),
            Text('Last 8 weeks',
                style: AppTheme.bodyLarge(color: AppColors.darkTextSecondary)),
            const SizedBox(height: AppSpacing.lg),

            Row(
              children: const [
                Expanded(child: StatChip(label: 'Sessions', value: '47')),
                SizedBox(width: AppSpacing.xs),
                Expanded(child: StatChip(label: 'Hours', value: '142')),
                SizedBox(width: AppSpacing.xs),
                Expanded(child: StatChip(label: 'Athletes', value: '34')),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            _ChartCard(
              title: 'Attendance',
              subtitle: 'Athletes per week',
              child: const _BarChart(
                values: [18, 22, 25, 24, 28, 31, 29, 34],
                labels: ['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7', 'W8'],
                color: AppColors.brandRed,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            _ChartCard(
              title: 'Group TRIMP',
              subtitle: 'Average per session',
              child: const _LineChart(
                values: [62, 71, 68, 84, 78, 92, 88, 95],
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            _ChartCard(
              title: 'Top athletes',
              subtitle: 'Most active this month',
              child: const _TopList(items: [
                ('Marko Å ariÄ‡', 24),
                ('Petra LeÅ¡iÄ‡', 21),
                ('Ivan BrkiÄ‡', 18),
                ('Ana MariÄ‡', 14),
                ('Luka KovaÄ', 12),
              ]),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.h2().copyWith(fontSize: 16)),
          Text(subtitle, style: AppTheme.caption()),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<int> values;
  final List<String> labels;
  final Color color;
  const _BarChart({
    required this.values,
    required this.labels,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final maxV = values.reduce(math.max).toDouble();
    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Text(
                      '${values[i]}',
                      style: AppTheme.micro(color: color)
                          .copyWith(fontSize: 10),
                    ),
                    const SizedBox(height: 2),
                    // The bar â€” Expanded gives it bounded height so
                    // FractionallySizedBox heightFactor actually means something.
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          widthFactor: 1,
                          heightFactor: (values[i] / maxV).clamp(0.05, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: color.withValues(
                                  alpha: 0.5 + (values[i] / maxV) * 0.5),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  spreadRadius: -2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(labels[i], style: AppTheme.micro()),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  final List<int> values;
  final Color color;
  const _LineChart({required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: CustomPaint(
        painter: _LinePainter(values: values, color: color),
        size: Size.infinite,
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<int> values;
  final Color color;
  _LinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce(math.min).toDouble();
    final maxV = values.reduce(math.max).toDouble();
    final range = maxV - minV == 0 ? 1 : maxV - minV;

    final stroke = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.4),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();
    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] - minV) / range) * size.height * 0.9;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.values != values;
}

class _TopList extends StatelessWidget {
  final List<(String, int)> items;
  const _TopList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: i == 0
                        ? AppColors.brandRed.withValues(alpha: 0.18)
                        : AppColors.darkBgTertiary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${i + 1}',
                    style: AppTheme.micro(
                      color:
                          i == 0 ? AppColors.brandRed : AppColors.darkTextPrimary,
                    ).copyWith(fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(items[i].$1, style: AppTheme.bodyLarge())),
                Text('${items[i].$2}', style: AppTheme.statNumber(fontSize: 14)),
                const SizedBox(width: 3),
                Text('sessions', style: AppTheme.caption()),
              ],
            ),
          ),
          if (i < items.length - 1)
            const Divider(color: AppColors.darkBorder, height: 1),
        ],
      ],
    );
  }
}