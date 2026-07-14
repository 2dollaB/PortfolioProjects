import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/clock_sync.dart';

/// Read-side view of a `sessions/{id}` doc — a cloud group session hosted by
/// the studio's trainer. (Write side lives in SessionRepository.)
class CloudSession {
  final String id;
  final String studioId;
  final String trainerUid;
  final String name;
  final String type; // always 'group' — sessions are group workouts only
  final String
  joinCode; // 6-digit code athletes enter/scan to join this session
  final String status; // 'live' | 'ended' — permission/joinable state
  final DateTime startedAt; // creation time (recent-list ordering)
  final DateTime? endedAt;

  // ── lifecycle (orthogonal to status) ──────────────────────
  final String runState; // 'lobby' | 'running' | 'paused'
  final DateTime? workoutStartedAt; // first Start; null in lobby
  final DateTime?
  runningSince; // start of current running segment; null if paused/lobby
  final int accumulatedMs; // elapsed before the current running segment
  final List<String> kickedUids;

  // ── interval timer config (set at launch) ──
  final int workSec; // 0 = no interval timer
  final int restSec;
  final int rounds;

  /// Shared 3-2-1 countdown length — [SessionRepository.beginWorkout] writes
  /// `runningSince` this far in the future so every client (trainer +
  /// athletes) counts down to the exact same instant.
  static const Duration countdownDuration = Duration(seconds: 3);

  const CloudSession({
    required this.id,
    required this.studioId,
    required this.trainerUid,
    required this.name,
    required this.type,
    this.joinCode = '',
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.runState = 'lobby',
    this.workoutStartedAt,
    this.runningSince,
    this.accumulatedMs = 0,
    this.kickedUids = const [],
    this.workSec = 0,
    this.restSec = 0,
    this.rounds = 1,
  });

  bool get isLive => status == 'live';

  bool get isLobby => runState == 'lobby';
  bool get isRunning => runState == 'running';
  bool get isPaused => runState == 'paused';
  bool isKicked(String uid) => kickedUids.contains(uid);
  bool get hasIntervals => workSec > 0;

  /// True while `runningSince` is still in the future — the trainer pressed
  /// Start but the synced 3-2-1 countdown hasn't reached zero yet. Uses
  /// [ClockSync.now] (not the raw device clock) since `runningSince` is
  /// meant to land at the same real-world instant on every phone.
  bool get isCountingDown =>
      isRunning &&
      runningSince != null &&
      ClockSync.now().isBefore(runningSince!);

  /// True once the workout is actually ticking (past the synced countdown).
  bool get isWorkoutLive => isRunning && !isCountingDown;

  /// Pause-aware live clock (lobby/running/paused). Identical math on every
  /// client: accumulated time plus the current running segment.
  Duration get liveElapsed {
    final base = Duration(milliseconds: accumulatedMs);
    final since = runningSince;
    if (since == null) return base; // paused or lobby
    final now = ClockSync.now();
    if (now.isBefore(since)) return base; // still counting down
    return base + now.difference(since);
  }

  Duration get duration => (endedAt ?? DateTime.now()).difference(startedAt);

  String get durationLabel {
    final m = duration.inMinutes;
    final h = m ~/ 60;
    final r = m % 60;
    return h > 0 ? '${h}h ${r}m' : '${m}m';
  }

  factory CloudSession.fromDoc(String id, Map<String, dynamic> d) {
    DateTime ts(dynamic v) => v is Timestamp
        ? v.toDate()
        : DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    return CloudSession(
      id: id,
      studioId: d['studioId'] as String? ?? '',
      trainerUid: d['trainerUid'] as String? ?? '',
      name: d['name'] as String? ?? 'Group session',
      type: d['type'] as String? ?? 'group',
      joinCode: d['joinCode'] as String? ?? '',
      status: d['status'] as String? ?? 'ended',
      startedAt: ts(d['startedAt']),
      endedAt: d['endedAt'] == null ? null : ts(d['endedAt']),
      // Docs predating this feature have no runState — treat them as running.
      runState: d['runState'] as String? ?? 'running',
      workoutStartedAt: d['workoutStartedAt'] == null
          ? null
          : ts(d['workoutStartedAt']),
      runningSince: d['runningSince'] == null ? null : ts(d['runningSince']),
      accumulatedMs: (d['accumulatedMs'] as num?)?.toInt() ?? 0,
      kickedUids:
          (d['kickedUids'] as List?)?.whereType<String>().toList() ?? const [],
      workSec: (d['workSec'] as num?)?.toInt() ?? 0,
      restSec: (d['restSec'] as num?)?.toInt() ?? 0,
      rounds: (d['rounds'] as num?)?.toInt() ?? 1,
    );
  }
}

/// What one live-board grid tile renders, regardless of source — built from
/// [SessionHrEntry] + a resolved name in production, or mock data in demo.
class BoardAthlete {
  final String id;
  final String name;
  final int bpm;
  final int avgBpm;
  final int hrMax;
  const BoardAthlete({
    required this.id,
    required this.name,
    required this.bpm,
    required this.avgBpm,
    required this.hrMax,
  });
}

/// One athlete's row on the live HR board (`sessions/{id}/hr/{uid}`).
class SessionHrEntry {
  final String uid;

  /// Denormalized display name, written by the athlete with each hr doc.
  /// Boards need it because athletes can't read each other's users/{uid}
  /// (only the studio owner can), so uid→name lookups fail for them.
  final String name;
  final int bpm;
  final int avgBpm; // athlete-computed running session average
  final int zone;
  final int hrMax;
  final DateTime lastUpdate;

  const SessionHrEntry({
    required this.uid,
    this.name = '',
    required this.bpm,
    required this.avgBpm,
    required this.zone,
    required this.hrMax,
    required this.lastUpdate,
  });

  factory SessionHrEntry.fromDoc(String uid, Map<String, dynamic> d) {
    final bpm = (d['bpm'] as num?)?.toInt() ?? 0;
    return SessionHrEntry(
      uid: uid,
      name: (d['name'] as String?) ?? '',
      bpm: bpm,
      avgBpm: (d['avgBpm'] as num?)?.toInt() ?? bpm,
      zone: (d['zone'] as num?)?.toInt() ?? 0,
      hrMax: (d['hrMax'] as num?)?.toInt() ?? 0,
      lastUpdate: d['lastUpdate'] is Timestamp
          ? (d['lastUpdate'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
