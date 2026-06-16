import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/theme.dart';
import '../models/user_profile.dart';
import '../models/workout_summary.dart';
import '../services/auth_service.dart';
import '../services/mock_data.dart';
import '../services/trainer_notes_repository.dart';
import '../services/workout_repository.dart';
import '../widgets/beat_button.dart';
import '../widgets/home_header.dart';
import '../widgets/mobile_frame.dart';
import '../widgets/stat_chip.dart';

/// Trainer-side detail view of a single member.
/// Shows profile + attendance heatmap + TRIMP trend + notes.
class MemberDetailScreen extends StatefulWidget {
  /// Demo (prototype) payload — seeded-random visuals. Null in production.
  final MockMember? member;

  /// Production payload — stats stream from the member's real workouts.
  final UserProfile? profile;

  const MemberDetailScreen({super.key, this.member, this.profile})
      : assert((member == null) != (profile == null),
            'Pass exactly one of member/profile');

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    if (p == null) {
      _notesCtrl.text =
          'Strong puller, weak push. Mention knee injury before plyo work.';
    } else {
      final uid = AuthService.currentUid;
      if (uid != null) {
        TrainerNotesRepository.load(uid, p.id).then((t) {
          if (mounted && t.isNotEmpty) _notesCtrl.text = t;
        });
      }
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveNotes() async {
    final p = widget.profile;
    final uid = AuthService.currentUid;
    var message = 'Notes saved';
    if (p != null && uid != null) {
      try {
        await TrainerNotesRepository.save(uid, p.id, _notesCtrl.text.trim());
      } catch (_) {
        message = 'Could not save notes.';
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static const int _heatmapWeeks = 12;
  static const int _trendWeeks = 8;

  /// Monday of the current week, at midnight.
  DateTime get _weekStart {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: today.weekday - 1));
  }

  /// 7×12 cell intensities (0 = rest day) from real workouts: cell brightness
  /// follows that day's TRIMP relative to the member's best day.
  List<List<double>> _heatmapFrom(List<WorkoutSummary> all) {
    final firstCol = _weekStart.subtract(Duration(days: 7 * (_heatmapWeeks - 1)));
    final byDay = <DateTime, int>{};
    for (final w in all) {
      final d = DateTime(w.startTime.year, w.startTime.month, w.startTime.day);
      byDay[d] = (byDay[d] ?? 0) + w.trimp;
    }
    final maxTrimp =
        byDay.values.isEmpty ? 1 : byDay.values.reduce(math.max).clamp(1, 1 << 31);
    return List.generate(7, (row) {
      return List.generate(_heatmapWeeks, (col) {
        final day = firstCol.add(Duration(days: col * 7 + row));
        final t = byDay[day];
        return t == null ? 0.0 : (t / maxTrimp).clamp(0.25, 1.0).toDouble();
      });
    });
  }

  /// Weekly TRIMP sums, oldest → newest, current week last.
  List<int> _trendFrom(List<WorkoutSummary> all) {
    return List.generate(_trendWeeks, (i) {
      final start = _weekStart.subtract(Duration(days: 7 * (_trendWeeks - 1 - i)));
      final end = start.add(const Duration(days: 7));
      return all
          .where((w) => !w.startTime.isBefore(start) && w.startTime.isBefore(end))
          .fold(0, (s, w) => s + w.trimp);
    });
  }

  /// Demo visuals: same per-cell Random sequence as the original mock screen.
  List<List<double>> _demoHeatmap(int seed) {
    final rng = math.Random(seed);
    return List.generate(7, (_) {
      return List.generate(_heatmapWeeks, (_) {
        final v = rng.nextDouble();
        return v > 0.65 ? v : 0.0;
      });
    });
  }

  List<int> _demoTrend(int seed) {
    final rng = math.Random(seed);
    return List.generate(_trendWeeks, (_) => 50 + rng.nextInt(60));
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    if (profile == null) {
      final m = widget.member!;
      return _content(
        context,
        name: m.name,
        email: m.email,
        lastSeen: m.lastSeen,
        active: m.lastSeen.contains('Active'),
        sessions: '${m.sessions}',
        avgTrimp: '78',
        avgHr: '142',
        heatmap: _demoHeatmap(m.name.hashCode),
        trend: _demoTrend(m.name.hashCode),
      );
    }
    return StreamBuilder<List<WorkoutSummary>>(
      stream: WorkoutRepository.watchRecent(profile.id, limit: 200),
      builder: (context, snap) {
        final all = snap.data;
        final loaded = all != null;
        int avg(num Function(WorkoutSummary) f) =>
            (all!.map(f).reduce((a, b) => a + b) / all.length).round();
        return _content(
          context,
          name: profile.name,
          email: profile.email,
          lastSeen: !loaded
              ? '…'
              : all.isEmpty
                  ? 'No workouts yet'
                  : 'Last workout · ${all.first.dateLabel}',
          active: false,
          sessions: loaded ? '${all.length}' : '–',
          avgTrimp: loaded && all.isNotEmpty ? '${avg((w) => w.trimp)}' : '–',
          avgHr: loaded && all.isNotEmpty ? '${avg((w) => w.avgHr)}' : '–',
          heatmap: loaded
              ? _heatmapFrom(all)
              : List.generate(7, (_) => List.filled(_heatmapWeeks, 0.0)),
          trend: loaded ? _trendFrom(all) : List.filled(_trendWeeks, 0),
        );
      },
    );
  }

  Widget _content(
    BuildContext context, {
    required String name,
    required String email,
    required String lastSeen,
    required bool active,
    required String sessions,
    required String avgTrimp,
    required String avgHr,
    required List<List<double>> heatmap,
    required List<int> trend,
  }) {
    return MobileFrame(
      child: Scaffold(
      backgroundColor: AppColors.bgPrimary,
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
                        HomeHeader.initialsOf(name),
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
                              color: AppColors.bgPrimary,
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
                      Text(name, style: AppTheme.h1().copyWith(fontSize: 22)),
                      const SizedBox(height: 2),
                      Text(email, style: AppTheme.caption()),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            active ? Icons.circle : Icons.access_time_rounded,
                            size: 10,
                            color: active
                                ? AppColors.success
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            lastSeen,
                            style: AppTheme.caption(
                              color: active
                                  ? AppColors.success
                                  : AppColors.textSecondary,
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
                Expanded(child: StatChip(label: 'Sessions', value: sessions)),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: StatChip(label: 'Avg TRIMP', value: avgTrimp)),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                    child: StatChip(label: 'Avg HR', value: avgHr, unit: 'bpm')),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            Text('Attendance · last 12 weeks', style: AppTheme.h2()),
            const SizedBox(height: AppSpacing.sm),
            _AttendanceHeatmap(intensities: heatmap),

            const SizedBox(height: AppSpacing.lg),
            Text('TRIMP trend · last 8 weeks', style: AppTheme.h2()),
            const SizedBox(height: AppSpacing.sm),
            _TrimpTrend(values: trend),

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
              onPressed: _saveNotes,
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Attendance heatmap — 7 day-rows × 12 week-columns.
/// Cell intensity 0 = rest day; >0 sets the trained-cell brightness.
class _AttendanceHeatmap extends StatelessWidget {
  final List<List<double>> intensities;
  const _AttendanceHeatmap({required this.intensities});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 12 / 7,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            for (int row = 0; row < 7; row++)
              Expanded(
                child: Row(
                  children: [
                    for (int col = 0; col < intensities[row].length; col++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(1.5),
                          child: _Cell(
                            intensity: intensities[row][col],
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
    final trained = intensity > 0;
    return Container(
      decoration: BoxDecoration(
        color: trained
            ? AppColors.brandRed.withValues(alpha: 0.3 + intensity * 0.5)
            : AppColors.bgTertiary,
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
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
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
