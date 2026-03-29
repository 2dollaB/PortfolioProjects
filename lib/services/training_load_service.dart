import '../models/workout.dart';

/// 8.3 — Training Load Service
/// Calculates acute (7d) and chronic (28d) training load
/// plus the Acute:Chronic Workload Ratio (ACWR).
class TrainingLoadService {
  /// Calculate rolling TRIMP for N days from now
  static double rollingTrimp(List<Workout> workouts, int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return workouts
        .where((w) => w.startTime.isAfter(cutoff))
        .fold<double>(0, (sum, w) => sum + w.analytics.trimp);
  }

  /// Acute load: last 7 days TRIMP
  static double acuteLoad(List<Workout> workouts) =>
      rollingTrimp(workouts, 7);

  /// Chronic load: last 28 days averaged to weekly
  static double chronicLoad(List<Workout> workouts) =>
      rollingTrimp(workouts, 28) / 4;

  /// ACWR ratio — ideal range 0.8-1.3
  static double acwr(List<Workout> workouts) {
    final chronic = chronicLoad(workouts);
    if (chronic <= 0) return 0;
    return acuteLoad(workouts) / chronic;
  }

  /// ACWR status label
  static ({String label, String emoji, TrainingZone zone}) acwrStatus(
      double ratio) {
    if (ratio <= 0) {
      return (label: 'No Data', emoji: '⏸️', zone: TrainingZone.none);
    }
    if (ratio < 0.8) {
      return (label: 'Undertraining', emoji: '🐢', zone: TrainingZone.low);
    }
    if (ratio <= 1.3) {
      return (label: 'Sweet Spot', emoji: '✅', zone: TrainingZone.optimal);
    }
    if (ratio <= 1.5) {
      return (label: 'High Risk', emoji: '⚠️', zone: TrainingZone.high);
    }
    return (label: 'Danger Zone', emoji: '🔴', zone: TrainingZone.danger);
  }

  /// Weekly TRIMP totals for the last N weeks (oldest first)
  static List<double> weeklyTrimps(List<Workout> workouts, {int weeks = 8}) {
    final now = DateTime.now();
    final result = List.filled(weeks, 0.0);
    for (final w in workouts) {
      final weeksAgo = now.difference(w.startTime).inDays ~/ 7;
      if (weeksAgo >= 0 && weeksAgo < weeks) {
        result[weeks - 1 - weeksAgo] += w.analytics.trimp;
      }
    }
    return result;
  }

  /// Weekly session counts for last N weeks (oldest first)
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

  /// Weekly avg HR for last N weeks (oldest first)
  static List<double> weeklyAvgHr(List<Workout> workouts, {int weeks = 8}) {
    final now = DateTime.now();
    final hrSums = List.filled(weeks, 0.0);
    final counts = List.filled(weeks, 0);
    for (final w in workouts) {
      final weeksAgo = now.difference(w.startTime).inDays ~/ 7;
      if (weeksAgo >= 0 && weeksAgo < weeks) {
        hrSums[weeks - 1 - weeksAgo] += w.analytics.avgHr;
        counts[weeks - 1 - weeksAgo]++;
      }
    }
    return List.generate(weeks, (i) =>
        counts[i] > 0 ? hrSums[i] / counts[i] : 0);
  }

  /// Zone distribution aggregated by week for last N weeks
  /// Returns Map of weekIdx to Map of zone to percentage
  static List<Map<int, double>> weeklyZoneDistribution(
      List<Workout> workouts, {int weeks = 8}) {
    final now = DateTime.now();
    final zoneSecs = List.generate(weeks, (_) => <int, int>{});
    for (final w in workouts) {
      final weeksAgo = now.difference(w.startTime).inDays ~/ 7;
      if (weeksAgo >= 0 && weeksAgo < weeks) {
        final idx = weeks - 1 - weeksAgo;
        for (final e in w.analytics.timeInZone.entries) {
          zoneSecs[idx][e.key] =
              (zoneSecs[idx][e.key] ?? 0) + e.value.inSeconds;
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

enum TrainingZone { none, low, optimal, high, danger }
