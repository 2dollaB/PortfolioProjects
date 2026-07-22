import '../models/workout.dart';

/// Descriptive weekly aggregators for the Trends screen. Purely factual —
/// counts and sums, no diagnostic load models (TRIMP/ACWR were removed).
class WorkoutStatsService {
  WorkoutStatsService._();

  /// Weekly BeatPoints totals for the last [weeks] weeks (oldest first).
  static List<int> weeklyBeatPoints(List<Workout> workouts, {int weeks = 8}) {
    final now = DateTime.now();
    final result = List.filled(weeks, 0);
    for (final w in workouts) {
      final weeksAgo = now.difference(w.startTime).inDays ~/ 7;
      if (weeksAgo >= 0 && weeksAgo < weeks) {
        result[weeks - 1 - weeksAgo] += w.analytics.beatPoints;
      }
    }
    return result;
  }
}
