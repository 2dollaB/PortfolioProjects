import 'package:cloud_firestore/cloud_firestore.dart';
import 'workout_repository.dart';

/// Time buckets the leaderboard can rank by.
enum LbPeriod { week, month, year, allTime }

/// Reads/writes `studios/{studioId}/leaderboard/{uid}` — a denormalized
/// per-athlete BeatPoints total that every studio member can read (they can't
/// read each other's raw `workouts`). Each athlete writes only their own entry;
/// there is no Cloud Function involved.
///
/// Period buckets carry the period *key* they were computed for (Monday date /
/// `YYYY-MM` / `YYYY`), so a reader can tell a stale bucket (last week's total)
/// from a live one and score it 0 for the current period.
class LeaderboardRepository {
  LeaderboardRepository._();

  static CollectionReference<Map<String, dynamic>> _col(String studioId) =>
      FirebaseFirestore.instance
          .collection('studios')
          .doc(studioId)
          .collection('leaderboard');

  /// Monday (local date) of the week [d] falls in — the week bucket key.
  static String weekKey(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    final monday = day.subtract(Duration(days: day.weekday - 1));
    return '${monday.year}-${_two(monday.month)}-${_two(monday.day)}';
  }

  static String monthKey(DateTime d) => '${d.year}-${_two(d.month)}';
  static String yearKey(DateTime d) => '${d.year}';
  static String _two(int n) => n.toString().padLeft(2, '0');

  /// Recomputes the caller's own leaderboard entry from all their workouts and
  /// writes it. Self-healing: it corrects drift and back-fills history the
  /// first time an athlete opens the board after this feature shipped. No-op
  /// without a studio.
  static Future<void> recomputeSelf({
    required String studioId,
    required String uid,
    required String name,
  }) async {
    final all = await WorkoutRepository.fetchAllForUser(uid);
    final now = DateTime.now();
    final wk = weekKey(now), mk = monthKey(now), yk = yearKey(now);
    var allTime = 0, week = 0, month = 0, year = 0;
    for (final w in all) {
      final bp = w.beatPoints;
      allTime += bp;
      if (yearKey(w.startTime) == yk) year += bp;
      if (monthKey(w.startTime) == mk) month += bp;
      if (weekKey(w.startTime) == wk) week += bp;
    }
    await _col(studioId).doc(uid).set({
      'name': name,
      'allTime': allTime,
      'year': year,
      'month': month,
      'week': week,
      'yearKey': yk,
      'monthKey': mk,
      'weekKey': wk,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Live leaderboard for a studio (all athletes' entries).
  static Stream<List<LeaderboardEntry>> watchStudio(String studioId) {
    return _col(studioId).snapshots().map(
          (snap) => snap.docs
              .map((d) => LeaderboardEntry.fromDoc(d.id, d.data()))
              .toList(),
        );
  }
}

class LeaderboardEntry {
  final String uid;
  final String name;
  final int allTime;
  final int week;
  final int month;
  final int year;
  final String weekKey;
  final String monthKey;
  final String yearKey;

  const LeaderboardEntry({
    required this.uid,
    required this.name,
    required this.allTime,
    required this.week,
    required this.month,
    required this.year,
    required this.weekKey,
    required this.monthKey,
    required this.yearKey,
  });

  /// Points for [period], scored 0 when the stored bucket belongs to a past
  /// period (e.g. the athlete didn't train this week).
  int pointsFor(LbPeriod period, DateTime now) {
    switch (period) {
      case LbPeriod.allTime:
        return allTime;
      case LbPeriod.year:
        return yearKey == LeaderboardRepository.yearKey(now) ? year : 0;
      case LbPeriod.month:
        return monthKey == LeaderboardRepository.monthKey(now) ? month : 0;
      case LbPeriod.week:
        return weekKey == LeaderboardRepository.weekKey(now) ? week : 0;
    }
  }

  factory LeaderboardEntry.fromDoc(String uid, Map<String, dynamic> d) {
    int i(String k) => (d[k] as num?)?.toInt() ?? 0;
    return LeaderboardEntry(
      uid: uid,
      name: (d['name'] as String?) ?? '',
      allTime: i('allTime'),
      week: i('week'),
      month: i('month'),
      year: i('year'),
      weekKey: (d['weekKey'] as String?) ?? '',
      monthKey: (d['monthKey'] as String?) ?? '',
      yearKey: (d['yearKey'] as String?) ?? '',
    );
  }
}
