import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../services/mock_data.dart';
import '../widgets/beat_button.dart';
import '../widgets/mobile_frame.dart';
import '../widgets/stat_chip.dart';

/// Trainer-side detail view of a single member.
/// Shows profile + attendance heatmap + TRIMP trend + notes.
class MemberDetailScreen extends StatefulWidget {
  final MockMember member;
  const MemberDetailScreen({super.key, required this.member});

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  final _notesCtrl = TextEditingController(
    text: 'Strong puller, weak push. Mention knee injury before plyo work.',
  );

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  String get _initials {
    final parts = widget.member.name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  /// Mock 8-week TRIMP trend, seeded from the member's name so it's stable
  /// across rebuilds.
  List<int> get _trimpTrend {
    final rng = math.Random(widget.member.name.hashCode);
    return List.generate(8, (i) => 50 + rng.nextInt(60));
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.member.lastSeen.contains('Active');
    return MobileFrame(
      child: Scaffold(
      backgroundColor: AppColors.darkBgPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl,
          ),
          children: [
            // Profile header
            Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.brandRed.withValues(alpha: 0.18),
                        border: Border.all(
                          color: AppColors.brandRed.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _initials,
                        style: AppTheme.h1(color: AppColors.brandRed)
                            .copyWith(fontWeight: FontWeight.w800, fontSize: 26),
                      ),
                    ),
                    if (active)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.darkBgPrimary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.member.name,
                          style: AppTheme.h1().copyWith(fontSize: 22)),
                      const SizedBox(height: 2),
                      Text(widget.member.email, style: AppTheme.caption()),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            active ? Icons.circle : Icons.access_time_rounded,
                            size: 10,
                            color: active
                                ? AppColors.success
                                : AppColors.darkTextSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.member.lastSeen,
                            style: AppTheme.caption(
                              color: active
                                  ? AppColors.success
                                  : AppColors.darkTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Quick stats
            Row(
              children: [
                Expanded(child: StatChip(
                  label: 'Sessions',
                  value: '${widget.member.sessions}',
                )),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: const StatChip(
                  label: 'Avg TRIMP',
                  value: '78',
                )),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: const StatChip(
                  label: 'Avg HR',
                  value: '142',
                  unit: 'bpm',
                )),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            Text('Attendance · last 12 weeks', style: AppTheme.h2()),
            const SizedBox(height: AppSpacing.sm),
            _AttendanceHeatmap(seed: widget.member.name.hashCode),

            const SizedBox(height: AppSpacing.lg),
            Text('TRIMP trend · last 8 weeks', style: AppTheme.h2()),
            const SizedBox(height: AppSpacing.sm),
            _TrimpTrend(values: _trimpTrend),

            const SizedBox(height: AppSpacing.lg),
            Text('Trainer notes', style: AppTheme.h2()),
            Text('Only you can see these.', style: AppTheme.caption()),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _notesCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Add notes about this athlete…',
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
            BeatPrimaryButton(
              label: 'Save notes',
              icon: Icons.check_rounded,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notes saved'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// 12-week attendance heatmap — 7 days × 12 cols.
/// Cell intensity = fake "attended that day" probability.
class _AttendanceHeatmap extends StatelessWidget {
  final int seed;
  const _AttendanceHeatmap({required this.seed});

  @override
  Widget build(BuildContext context) {
    final rng = math.Random(seed);
    return AspectRatio(
      aspectRatio: 12 / 7,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.darkBgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.darkBorder),
        ),
        child: Column(
          children: [
            for (int row = 0; row < 7; row++)
              Expanded(
                child: Row(
                  children: [
                    for (int col = 0; col < 12; col++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(1.5),
                          child: _Cell(
                            intensity: rng.nextDouble(),
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

class _Cell extends StatelessWidget {
  final double intensity;
  const _Cell({required this.intensity});

  @override
  Widget build(BuildContext context) {
    // Only ~30% of cells are "trained" days for realism
    final trained = intensity > 0.65;
    return Container(
      decoration: BoxDecoration(
        color: trained
            ? AppColors.brandRed.withValues(alpha: 0.3 + intensity * 0.5)
            : AppColors.darkBgTertiary,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

/// 8-week TRIMP line chart.
class _TrimpTrend extends StatelessWidget {
  final List<int> values;
  const _TrimpTrend({required this.values});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.darkBgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: SizedBox(
        height: 100,
        child: CustomPaint(
          painter: _TrimpLinePainter(values: values),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _TrimpLinePainter extends CustomPainter {
  final List<int> values;
  _TrimpLinePainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce(math.min).toDouble();
    final maxV = values.reduce(math.max).toDouble();
    final range = maxV - minV == 0 ? 1 : maxV - minV;

    final stroke = Paint()
      ..color = AppColors.warning
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.warning.withValues(alpha: 0.4),
          AppColors.warning.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fill = Path();
    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = size.height -
          ((values[i] - minV) / range) * size.height * 0.85;
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
      // Dot at each point
      canvas.drawCircle(
        Offset(x, y),
        3,
        Paint()..color = AppColors.warning,
      );
    }
    fill.lineTo(size.width, size.height);
    fill.close();
    canvas.drawPath(fill, fillPaint);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _TrimpLinePainter old) => old.values != values;
}
