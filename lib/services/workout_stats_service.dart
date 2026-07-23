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

  /// Weekly training minutes for the last [weeks] weeks (oldest first).
  static List<int> weeklyMinutes(List<Workout> workouts, {int weeks = 8}) {
    final now = DateTime.now();
    final result = List.filled(weeks, 0);
    for (final w in workouts) {
      final weeksAgo = now.difference(w.startTime).inDays ~/ 7;
      if (weeksAgo >= 0 && weeksAgo < weeks) {
        result[weeks - 1 - weeksAgo] += w.duration.inMinutes;
      }
    }
    return result;
  }

  /// Weekly session counts for the last [weeks] weeks (oldest first).
  static List<int> weeklySessions(List<Workout> workouts, {int weeks = 8}) {
    final now = DateTime.now();
    final result = List.filled(weeks, 0);
    for (final w in workouts) {
      final weeksAgo = now.difference(w.startTime).inDays ~/ 7;
      if (weeksAgo >= 0 && weeksAgo < weeks) {
        result[weeks - 1 - weeksAgo]++;
      }
    }
    return result;
  }

  /// Zone distribution aggregated by week (weekIdx → zone → percentage).
  static List<Map<int, double>> weeklyZoneDistribution(
    List<Workout> workouts, {
    int weeks = 8,
  }) {
    final now = DateTime.now();
    final zoneSecs = List.generate(weeks, (_) => <int, int>{});
    for (final w in workouts) {
      final weeksAgo = now.difference(w.startTime).inDays ~/ 7;
      if (weeksAgo >= 0 && weeksAgo < weeks) {
        final idx = weeks - 1 - weeksAgo;
        for (final e in w.analytics.timeInZone.entries) {
          zoneSecs[idx][e.key] = (zoneSecs[idx][e.key] ?? 0) + e.value.inSeconds;
        }
      }
    }
    return zoneSecs.map((weekZones) {
      final total = weekZones.values.fold<int>(0, (a, b) => a + b);
      if (total == 0) return <int, double>{};
      return weekZones.map((z, s) => MapEntry(z, s / total * 100));
    }).toList();
  }
}
