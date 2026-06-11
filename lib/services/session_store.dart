import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../widgets/workout_type_sheet.dart';
import 'mock_data.dart';

/// In-memory session state for the prototype.
///
/// Holds at most one **live** session at a time + a growing list of **past**
/// session records. Notifies via [ValueNotifier]s so any screen can listen.
///
/// When the real backend lands, swap this class out for Firestore listeners —
/// same API surface, no UI changes needed.
class SessionStore {
  SessionStore._() {
    _seedHistory();
  }

  static final SessionStore instance = SessionStore._();

  /// Currently-running session, or null when nothing is live.
  final ValueNotifier<LiveSession?> live = ValueNotifier(null);

  /// Past sessions, newest first.
  final ValueNotifier<List<SessionRecord>> history = ValueNotifier([]);

  /// Whether a session is currently in progress.
  bool get isLive => live.value != null;

  // ── Mutations ──

  /// Start a new live session. Picks the first [athleteCount] mock participants.
  void startLive({
    required String name,
    required WorkoutType type,
    int athleteCount = 10,
    int workSec = 45,
    int restSec = 20,
    int rounds = 8,
  }) {
    live.value = LiveSession(
      id: 'live-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      type: type,
      startedAt: DateTime.now(),
      athleteCount: athleteCount,
      workSec: workSec,
      restSec: restSec,
      rounds: rounds,
    );
  }

  /// End the current live session, capturing analytics + moving to history.
  /// Returns the newly-stored record (also added to [history]).
  SessionRecord? endLive() {
    final l = live.value;
    if (l == null) return null;

    final endedAt = DateTime.now();
    final durationMin =
        math.max(1, endedAt.difference(l.startedAt).inMinutes);

    final participants = MockData.liveOf(l.athleteCount);
    final rng = math.Random();
    final results = <AthleteResult>[];
    for (final p in participants) {
      // Realistic per-athlete numbers based on baseline BPM + duration.
      final avg = p.avgBpm + rng.nextInt(8) - 4;
      final max = avg + 18 + rng.nextInt(15);
      final trimp = (durationMin * (avg / 180) * 1.85).round();
      final cal = (durationMin * (avg / 180) * 8.5 * 1.0).round();
      // Zone distribution (Z0..Z5) percentages summing to 100.
      final dist = _mockZoneDistribution(rng);
      results.add(AthleteResult(
        athleteId: p.id,
        name: p.name,
        avgBpm: avg,
        maxBpm: max,
        trimp: trimp,
        calories: cal,
        timeInZones: dist,
      ));
    }

    final avgGroupBpm =
        results.map((r) => r.avgBpm).reduce((a, b) => a + b) ~/ results.length;
    final groupTrimp =
        results.map((r) => r.trimp).reduce((a, b) => a + b) ~/ results.length;

    final record = SessionRecord(
      id: l.id,
      name: l.name,
      type: l.type,
      startedAt: l.startedAt,
      endedAt: endedAt,
      durationMin: durationMin,
      athleteCount: l.athleteCount,
      avgGroupBpm: avgGroupBpm,
      groupTrimp: groupTrimp,
      results: results,
    );

    history.value = [record, ...history.value];
    live.value = null;
    return record;
  }

  /// Convenience: today's session count.
  int get todaysSessionCount {
    final today = DateTime.now();
    return history.value
        .where((r) =>
            r.startedAt.year == today.year &&
            r.startedAt.month == today.month &&
            r.startedAt.day == today.day)
        .length;
  }

  // ── Internals ──

  List<int> _mockZoneDistribution(math.Random rng) {
    // Z1..Z5 percentages (Z0 = 0 during active session)
    final z1 = 5 + rng.nextInt(10);
    final z2 = 10 + rng.nextInt(15);
    final z4 = 20 + rng.nextInt(20);
    final z5 = 5 + rng.nextInt(15);
    final z3 = 100 - z1 - z2 - z4 - z5;
    return [0, z1, z2, z3 < 0 ? 0 : z3, z4, z5];
  }

  void _seedHistory() {
    // Pre-seed 3 past sessions so demo screens always have content.
    final now = DateTime.now();
    history.value = [
      _fakeRecord(
        name: 'Friday HIIT 18:00',
        type: WorkoutType.hiit,
        startedAt: now.subtract(const Duration(hours: 18)),
        durationMin: 42,
        athleteCount: 14,
        groupTrimp: 92,
      ),
      _fakeRecord(
        name: 'Wednesday Strength',
        type: WorkoutType.strength,
        startedAt: now.subtract(const Duration(days: 2)),
        durationMin: 55,
        athleteCount: 9,
        groupTrimp: 68,
      ),
      _fakeRecord(
        name: 'Monday Endurance',
        type: WorkoutType.endurance,
        startedAt: now.subtract(const Duration(days: 4)),
        durationMin: 72,
        athleteCount: 12,
        groupTrimp: 104,
      ),
    ];
  }

  SessionRecord _fakeRecord({
    required String name,
    required WorkoutType type,
    required DateTime startedAt,
    required int durationMin,
    required int athleteCount,
    required int groupTrimp,
  }) {
    final rng = math.Random(name.hashCode);
    final participants = MockData.liveOf(athleteCount);
    final results = participants
        .map((p) => AthleteResult(
              athleteId: p.id,
              name: p.name,
              avgBpm: p.avgBpm + rng.nextInt(8) - 4,
              maxBpm: p.bpm + 8 + rng.nextInt(15),
              trimp: groupTrimp + rng.nextInt(20) - 10,
              calories: (durationMin * 7.5 + rng.nextInt(50)).round(),
              timeInZones: _mockZoneDistribution(rng),
            ))
        .toList();
    final avgGroupBpm =
        results.map((r) => r.avgBpm).reduce((a, b) => a + b) ~/ results.length;
    return SessionRecord(
      id: 'past-${startedAt.millisecondsSinceEpoch}',
      name: name,
      type: type,
      startedAt: startedAt,
      endedAt: startedAt.add(Duration(minutes: durationMin)),
      durationMin: durationMin,
      athleteCount: athleteCount,
      avgGroupBpm: avgGroupBpm,
      groupTrimp: groupTrimp,
      results: results,
    );
  }
}

// ─── Models ────────────────────────────────────────────────────

class LiveSession {
  final String id;
  final String name;
  final WorkoutType type;
  final DateTime startedAt;
  final int athleteCount;
  final int workSec;
  final int restSec;
  final int rounds;

  LiveSession({
    required this.id,
    required this.name,
    required this.type,
    required this.startedAt,
    required this.athleteCount,
    required this.workSec,
    required this.restSec,
    required this.rounds,
  });
}

class SessionRecord {
  final String id;
  final String name;
  final WorkoutType type;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationMin;
  final int athleteCount;
  final int avgGroupBpm;
  final int groupTrimp;
  final List<AthleteResult> results;

  SessionRecord({
    required this.id,
    required this.name,
    required this.type,
    required this.startedAt,
    required this.endedAt,
    required this.durationMin,
    required this.athleteCount,
    required this.avgGroupBpm,
    required this.groupTrimp,
    required this.results,
  });

  String get durationLabel {
    final h = durationMin ~/ 60;
    final m = durationMin % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class AthleteResult {
  final String athleteId;
  final String name;
  final int avgBpm;
  final int maxBpm;
  final int trimp;
  final int calories;

  /// Zone distribution Z0..Z5 as integer percentages (sum ≈ 100).
  final List<int> timeInZones;

  AthleteResult({
    required this.athleteId,
    required this.name,
    required this.avgBpm,
    required this.maxBpm,
    required this.trimp,
    required this.calories,
    required this.timeInZones,
  });

  /// The zone the athlete spent the most time in (1..5).
  int get dominantZone {
    int best = 1;
    int max = 0;
    for (int z = 1; z < timeInZones.length; z++) {
      if (timeInZones[z] > max) {
        max = timeInZones[z];
        best = z;
      }
    }
    return best;
  }
}
