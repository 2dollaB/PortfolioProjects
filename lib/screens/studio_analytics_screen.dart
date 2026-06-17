import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../widgets/mobile_frame.dart';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../models/studio.dart';
import '../models/user_profile.dart';
import '../models/workout_summary.dart';
import '../services/auth_service.dart';
import '../services/studio_repository.dart';
import '../services/user_repository.dart';
import '../services/workout_repository.dart';
import '../widgets/stat_chip.dart';

class StudioAnalyticsScreen extends StatefulWidget {
  /// Production: the signed-in trainer's studio to aggregate over.
  /// Null (prototype/demo) keeps the mock visuals.
  final String? studioId;
  const StudioAnalyticsScreen({super.key, this.studioId});

  @override
  State<StudioAnalyticsScreen> createState() => _StudioAnalyticsScreenState();
}

class _StudioAnalyticsScreenState extends State<StudioAnalyticsScreen> {
  Stream<Studio?>? _studioStream;

  // Memoized aggregation, refreshed when the member list changes.
  Future<_Analytics>? _future;
  List<String>? _uids;

  static final _demo = _Analytics(
    sessions: '47',
    hours: '142',
    athletes: '34',
    attendance: const [18, 22, 25, 24, 28, 31, 29, 34],
    groupTrimp: const [62, 71, 68, 84, 78, 92, 88, 95],
    top: const [
      ('Marko Šarić', 24),
      ('Petra Lešić', 21),
      ('Ivan Brkić', 18),
      ('Ana Marić', 14),
      ('Luka Kovač', 12),
    ],
  );

  @override
  void initState() {
    super.initState();
    final sid = widget.studioId;
    if (AuthService.currentUid != null && sid != null) {
      _studioStream = StudioRepository.watch(sid);
    }
  }

  Future<_Analytics> _analyticsFor(Studio studio) {
    final uids = studio.athleteUids;
    if (_future == null || !listEquals(_uids, uids)) {
      _uids = List.of(uids);
      _future = _load(uids);
    }
    return _future!;
  }

  static Future<_Analytics> _load(List<String> uids) async {
    final members = await UserRepository.loadMany(uids);
    final workouts = await Future.wait(
      members.map((m) => WorkoutRepository.fetchRecent(m.id, limit: 100)),
    );
    return _Analytics.compute(members, workouts);
  }

  @override
  Widget build(BuildContext context) {
    final stream = _studioStream;
    if (stream == null) return _content(context, _demo);
    return StreamBuilder<Studio?>(
      stream: stream,
      builder: (context, snap) {
        final studio = snap.data;
        if (studio == null) return _loading(context);
        return FutureBuilder<_Analytics>(
          future: _analyticsFor(studio),
          builder: (context, asnap) {
            final a = asnap.data;
            if (a == null) return _loading(context);
            return _content(context, a);
          },
        );
      },
    );
  }

  Widget _header() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(Strings.analytics, style: AppTheme.h1().copyWith(fontSize: 26)),
          const SizedBox(height: AppSpacing.xs),
          Text(Strings.last8Weeks,
              style: AppTheme.bodyLarge(color: AppColors.textSecondary)),
        ],
      );

  Widget _loading(BuildContext context) {
    return MobileFrame(
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        body: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, _Analytics a) {
    return MobileFrame(
      child: Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl,
          ),
          children: [
            _header(),
            const SizedBox(height: AppSpacing.lg),

            Row(
              children: [
                Expanded(child: StatChip(label: Strings.sessions, value: a.sessions)),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: StatChip(label: Strings.hours, value: a.hours)),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: StatChip(label: Strings.athletes, value: a.athletes)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            _ChartCard(
              title: Strings.attendanceTitle,
              subtitle: Strings.athletesPerWeek,
              child: _BarChart(
                values: a.attendance,
                labels: const ['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7', 'W8'],
                color: AppColors.brandRed,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            _ChartCard(
              title: Strings.groupTrimp,
              subtitle: Strings.averagePerSession,
              child: _LineChart(
                values: a.groupTrimp,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            _ChartCard(
              title: Strings.topAthletes,
              subtitle: Strings.mostActiveMonth,
              child: a.top.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Text(
                        Strings.noWorkoutsMonth,
                        style: AppTheme.caption(),
                      ),
                    )
                  : _TopList(items: a.top),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Aggregated studio numbers over the last 8 weeks (production: computed from
/// members' workouts; demo: the original mock constants).
class _Analytics {
  final String sessions;
  final String hours;
  final String athletes;
  final List<int> attendance; // distinct athletes per week, oldest first
  final List<int> groupTrimp; // avg TRIMP per session per week
  final List<(String, int)> top; // name + sessions in the last 30 days

  const _Analytics({
    required this.sessions,
    required this.hours,
    required this.athletes,
    required this.attendance,
    required this.groupTrimp,
    required this.top,
  });

  factory _Analytics.compute(
    List<UserProfile> members,
    List<List<WorkoutSummary>> workoutsPerMember,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    // 8 buckets: index 0 = 7 weeks ago, index 7 = current week.
    final windowStart = weekStart.subtract(const Duration(days: 7 * 7));

    var sessions = 0;
    var minutes = 0;
    final attendance = List<int>.filled(8, 0);
    final trimpSum = List<int>.filled(8, 0);
    final trimpCount = List<int>.filled(8, 0);
    final top = <(String, int)>[];

    for (var i = 0; i < members.length; i++) {
      final weeksAttended = <int>{};
      var monthCount = 0;
      for (final w in workoutsPerMember[i]) {
        final week = w.startTime.difference(windowStart).inDays ~/ 7;
        if (week < 0 || week > 7) continue;
        sessions++;
        minutes += w.durationMin;
        weeksAttended.add(week);
        trimpSum[week] += w.trimp;
        trimpCount[week]++;
        if (now.difference(w.startTime).inDays <= 30) monthCount++;
      }
      for (final week in weeksAttended) {
        attendance[week]++;
      }
      if (monthCount > 0) top.add((members[i].name, monthCount));
    }
    top.sort((a, b) => b.$2.compareTo(a.$2));

    return _Analytics(
      sessions: '$sessions',
      hours: '${(minutes / 60).round()}',
      athletes: '${members.length}',
      attendance: attendance,
      groupTrimp: List.generate(
        8,
        (i) => trimpCount[i] == 0 ? 0 : (trimpSum[i] / trimpCount[i]).round(),
      ),
      top: top.take(5).toList(),
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
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
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
    // max(1, …) so an all-zero week set (new studio) doesn't divide by zero.
    final maxV = math.max(1, values.reduce(math.max)).toDouble();
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
                    // The bar — Expanded gives it bounded height so
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
                        : AppColors.bgTertiary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${i + 1}',
                    style: AppTheme.micro(
                      color:
                          i == 0 ? AppColors.brandRed : AppColors.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(items[i].$1, style: AppTheme.bodyLarge())),
                Text('${items[i].$2}', style: AppTheme.statNumber(fontSize: 14)),
                const SizedBox(width: 3),
                Text(Strings.sessionsLower, style: AppTheme.caption()),
              ],
            ),
          ),
          if (i < items.length - 1)
            Divider(color: AppColors.border, height: 1),
        ],
      ],
    );
  }
}
