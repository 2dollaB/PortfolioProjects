import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cloud_session.dart';
import 'clock_sync.dart';

/// Writes/reads `sessions/{id}` and its `hr/{uid}` live-HR subcollection.
/// Rules: only the studio owner creates/updates sessions; members read;
/// athletes write their own hr doc while the session is live.
class SessionRepository {
  SessionRepository._();

  static final CollectionReference<Map<String, dynamic>> _sessions =
      FirebaseFirestore.instance.collection('sessions');

  static final CollectionReference<Map<String, dynamic>> _sessionCodes =
      FirebaseFirestore.instance.collection('session_codes');

  static String _generateJoinCode() {
    final r = math.Random();
    return List.generate(6, (_) => r.nextInt(10)).join();
  }

  /// Opens a session in [studioId] in the **lobby** state — joinable (status
  /// 'live') but the workout clock hasn't started yet. Athletes join by
  /// entering/scanning the returned 6-digit [joinCode]. Returns the new id.
  static Future<String> start({
    required String studioId,
    required String trainerUid,
    required String name,
    required String type,
    int workSec = 0,
    int restSec = 0,
    int rounds = 1,
  }) async {
    // Enforce one live session per studio: end any leftovers first (e.g. a
    // session whose monitor tab was closed without ending it).
    await _endExistingLive(studioId);
    final joinCode = _generateJoinCode();
    final ref = await _sessions.add({
      'studioId': studioId,
      'trainerUid': trainerUid,
      'name': name,
      'type': type,
      'joinCode': joinCode,
      'status': 'live',
      'startedAt': FieldValue.serverTimestamp(),
      'runState': 'lobby',
      'workoutStartedAt': null,
      'runningSince': null,
      'accumulatedMs': 0,
      'kickedUids': <String>[],
      'workSec': workSec,
      'restSec': restSec,
      'rounds': rounds,
    });
    // Code → session lookup (rule checks the caller owns the studio, so it must
    // run after the session write above).
    await _sessionCodes.doc(joinCode).set({
      'sessionId': ref.id,
      'studioId': studioId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Resolves a 6-digit session code to its live session, or null if the code
  /// is unknown or its session is no longer live. Membership is enforced
  /// separately (the caller checks studio membership; rules block the rest).
  static Future<CloudSession?> resolveByCode(String code) async {
    final lookup = await _sessionCodes.doc(code.trim()).get();
    final sessionId = lookup.data()?['sessionId'] as String?;
    if (sessionId == null) return null;
    final doc = await _sessions.doc(sessionId).get();
    if (!doc.exists) return null;
    final session = CloudSession.fromDoc(doc.id, doc.data()!);
    return session.isLive ? session : null;
  }

  /// Ends every still-live session in the studio (used before opening a new
  /// one so there's never more than one live session for athletes to find).
  static Future<void> _endExistingLive(String studioId) async {
    final snap = await _sessions
        .where('studioId', isEqualTo: studioId)
        .where('status', isEqualTo: 'live')
        .get();
    for (final d in snap.docs) {
      await d.reference.update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
        'runState': 'ended',
        'runningSince': null,
      });
    }
  }

  /// Trainer presses Start — writes a shared future instant
  /// ([CloudSession.countdownDuration] out) as `runningSince` so every
  /// athlete's device (and the trainer's own) counts down to the exact same
  /// moment instead of each starting its own untimed countdown.
  static Future<void> beginWorkout(String sessionId) {
    final startsAt = ClockSync.now().add(CloudSession.countdownDuration);
    return _sessions.doc(sessionId).update({
      'runState': 'running',
      'workoutStartedAt': FieldValue.serverTimestamp(),
      'runningSince': Timestamp.fromDate(startsAt),
      'accumulatedMs': 0,
    });
  }

  /// Freeze the clock. [accumulatedMs] is the caller-computed total elapsed up
  /// to this moment (previous accumulated + the segment since runningSince).
  static Future<void> pause(String sessionId, {required int accumulatedMs}) {
    return _sessions.doc(sessionId).update({
      'runState': 'paused',
      'accumulatedMs': accumulatedMs,
      'runningSince': null,
    });
  }

  static Future<void> resume(String sessionId) {
    return _sessions.doc(sessionId).update({
      'runState': 'running',
      'runningSince': FieldValue.serverTimestamp(),
    });
  }

  /// Remove an athlete from the session and block their rejoin (their app sees
  /// the kick and self-leaves; the hardened hr rule also rejects their writes).
  static Future<void> kick(String sessionId, String uid) {
    return _sessions.doc(sessionId).update({
      'kickedUids': FieldValue.arrayUnion([uid]),
    });
  }

  /// Streams a single session doc (lifecycle for athletes/TV/monitor).
  static Stream<CloudSession?> watch(String sessionId) {
    return _sessions
        .doc(sessionId)
        .snapshots()
        .map((d) => d.exists ? CloudSession.fromDoc(d.id, d.data()!) : null);
  }

  static Future<void> end(String sessionId) {
    return _sessions.doc(sessionId).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
      'runState': 'ended',
      'runningSince': null,
    });
  }

  /// The studio's currently live session, or null. (Equality-only query so
  /// no composite index is needed; the app keeps at most one live session.)
  static Stream<CloudSession?> watchLive(String studioId) {
    return _sessions
        .where('studioId', isEqualTo: studioId)
        .where('status', isEqualTo: 'live')
        .limit(1)
        .snapshots()
        .map(
          (snap) => snap.docs.isEmpty
              ? null
              : CloudSession.fromDoc(
                  snap.docs.first.id,
                  snap.docs.first.data(),
                ),
        );
  }

  /// One-shot: sessions started on/after [since], newest first. Used for the
  /// trainer-home "Active today" / "Sessions / wk" stats. Reuses the
  /// studioId+startedAt index (equality on studioId, range on startedAt).
  static Future<List<CloudSession>> fetchSince(
    String studioId,
    DateTime since,
  ) async {
    final snap = await _sessions
        .where('studioId', isEqualTo: studioId)
        .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('startedAt', descending: true)
        .get();
    return snap.docs.map((d) => CloudSession.fromDoc(d.id, d.data())).toList();
  }

  /// Past + current sessions, newest first (studioId+startedAt index).
  static Stream<List<CloudSession>> watchRecent(
    String studioId, {
    int limit = 20,
  }) {
    return _sessions
        .where('studioId', isEqualTo: studioId)
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => CloudSession.fromDoc(d.id, d.data()))
              .toList(),
        );
  }

  /// Athlete-side ~1/sec heartbeat into the live board. Merge-set so the
  /// first write creates the doc.
  static Future<void> writeHr({
    required String sessionId,
    required String uid,
    required String name,
    required int bpm,
    required int avgBpm,
    required int zone,
    required int hrMax,
  }) {
    return _sessions.doc(sessionId).collection('hr').doc(uid).set({
      // Denormalized so co-athletes' boards can show names without users/
      // reads (rules keep users/{uid} owner+self only).
      'name': name,
      'bpm': bpm,
      'avgBpm': avgBpm,
      'zone': zone,
      'hrMax': hrMax,
      'lastUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Removes the athlete's row when they leave (only works while the session
  /// is still live — rules block hr writes after it ends).
  static Future<void> removeHr({
    required String sessionId,
    required String uid,
  }) {
    return _sessions.doc(sessionId).collection('hr').doc(uid).delete();
  }

  /// The live HR board (trainer monitor / TV view).
  static Stream<List<SessionHrEntry>> watchHr(String sessionId) {
    return _sessions
        .doc(sessionId)
        .collection('hr')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => SessionHrEntry.fromDoc(d.id, d.data()))
              .toList(),
        );
  }
}
