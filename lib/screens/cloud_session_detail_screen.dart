import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_spacing.dart';
import '../config/strings.dart';
import '../config/theme.dart';
import '../models/cloud_session.dart';
import '../models/workout_summary.dart';
import '../services/session_store.dart';
import '../services/user_repository.dart';
import '../services/workout_repository.dart';
import '../widgets/beat_button.dart';
import '../widgets/mobile_frame.dart';
import '../widgets/workout_type_sheet.dart';
import 'session_detail_screen.dart';

/// Post-session analytics for an ended cloud session.
///
/// Loads the athletes' saved workouts (linked by `sessionId`), resolves
/// their names, and renders the existing [SessionDetailScreen] through a
/// [SessionRecord] adapter — one analytics screen for both demo and cloud.
/// Results trickle in: an athlete's row appears once they end their workout.
class CloudSessionDetailScreen extends StatefulWidget {
  final CloudSession session;
  const CloudSessionDetailScreen({super.key, required this.session});

  @override
  State<CloudSessionDetailScreen> createState() =>
      _CloudSessionDetailScreenState();
}

class _CloudSessionDetailScreenState extends State<CloudSessionDetailScreen> {
  SessionRecord? _record;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final workouts =
          await WorkoutRepository.fetchBySession(widget.session.id);
      Map<String, String> names = const {};
      if (workouts.isNotEmpty) {
        final uids =
            workouts.map((w) => w.userId).whereType<String>().toSet().toList();
        final profiles = await UserRepository.loadMany(uids);
        names = {for (final p in profiles) p.id: p.name};
      }
      if (!mounted) return;
      setState(() {
        _record = workouts.isEmpty
            ? null
            : _toRecord(widget.session, workouts, names);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  /// Adapts cloud data into the demo screen's read model. Group numbers are
  /// per-athlete averages, matching what the demo store computes.
  static SessionRecord _toRecord(
    CloudSession s,
    List<WorkoutSummary> workouts,
    Map<String, String> names,
  ) {
    final results = [
      for (final w in workouts)
        AthleteResult(
          athleteId: w.userId ?? w.id,
          name: names[w.userId] ?? Strings.athlete,
          avgBpm: w.avgHr,
          maxBpm: w.maxHr,
          trimp: w.trimp,
          calories: w.calories,
          timeInZones: w.zoneDist,
        ),
    ]..sort((a, b) => b.trimp.compareTo(a.trimp));
    final n = results.length;
    return SessionRecord(
      id: s.id,
      name: s.name,
      type: WorkoutType.values.firstWhere(
        (t) => t.name == s.type,
        orElse: () => WorkoutType.hiit,
      ),
      startedAt: s.startedAt,
      endedAt: s.endedAt ?? s.startedAt,
      durationMin: s.duration.inMinutes,
      athleteCount: n,
      avgGroupBpm:
          (results.fold<int>(0, (sum, r) => sum + r.avgBpm) / n).round(),
      groupTrimp:
          (results.fold<int>(0, (sum, r) => sum + r.trimp) / n).round(),
      results: results,
    );
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;
    if (record != null) return SessionDetailScreen(record: record);

    return MobileFrame(
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          title: Text(Strings.sessionAnalytics),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: _loading
                ? const CircularProgressIndicator()
                : Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _failed
                              ? Icons.cloud_off_rounded
                              : Icons.hourglass_empty_rounded,
                          size: 40,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _failed
                              ? Strings.couldNotLoadResults
                              : Strings.noSavedWorkoutsYet,
                          style: AppTheme.bodyLarge(
                              color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        BeatSecondaryButton(
                          label: Strings.refresh,
                          icon: Icons.refresh_rounded,
                          onPressed: _load,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        BeatPrimaryButton(
                          label: Strings.backToHome,
                          icon: Icons.home_rounded,
                          onPressed: () => Navigator.of(context)
                              .popUntil((r) => r.isFirst),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
