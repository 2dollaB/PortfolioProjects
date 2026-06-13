import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cloud_session.dart';

/// Writes/reads `sessions/{id}` and its `hr/{uid}` live-HR subcollection.
/// Rules: only the studio owner creates/updates sessions; members read;
/// athletes write their own hr doc while the session is live.
class SessionRepository {
  SessionRepository._();

  static final CollectionReference<Map<String, dynamic>> _sessions =
      FirebaseFirestore.instance.collection('sessions');

  /// Starts a live session in [studioId]; returns the new session id.
  static Future<String> start({
    required String studioId,
    required String trainerUid,
    required String name,
    required String type,
  }) async {
    final ref = await _sessions.add({
      'studioId': studioId,
      'trainerUid': trainerUid,
      'name': name,
      'type': type,
      'status': 'live',
      'startedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  static Future<void> end(String sessionId) {
    return _sessions.doc(sessionId).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
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
        .map((snap) => snap.docs.isEmpty
            ? null
            : CloudSession.fromDoc(snap.docs.first.id, snap.docs.first.data()));
  }

  /// One-shot: sessions started on/after [since], newest first. Used for the
  /// trainer-home "Active today" / "Sessions / wk" stats. Reuses the
  /// studioId+startedAt index (equality on studioId, range on startedAt).
  static Future<List<CloudSession>> fetchSince(
      String studioId, DateTime since) async {
    final snap = await _sessions
        .where('studioId', isEqualTo: studioId)
        .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .orderBy('startedAt', descending: true)
        .get();
    return snap.docs
        .map((d) => CloudSession.fromDoc(d.id, d.data()))
        .toList();
  }

  /// Past + current sessions, newest first (studioId+startedAt index).
  static Stream<List<CloudSession>> watchRecent(String studioId,
      {int limit = 20}) {
    return _sessions
        .where('studioId', isEqualTo: studioId)
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CloudSession.fromDoc(d.id, d.data()))
            .toList());
  }

  /// Athlete-side ~1/sec heartbeat into the live board. Merge-set so the
  /// first write creates the doc.
  static Future<void> writeHr({
    required String sessionId,
    required String uid,
    required int bpm,
    required int avgBpm,
    required int zone,
    required int hrMax,
  }) {
    return _sessions.doc(sessionId).collection('hr').doc(uid).set({
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
    return _sessions.doc(sessionId).collection('hr').snapshots().map(
        (snap) => snap.docs
            .map((d) => SessionHrEntry.fromDoc(d.id, d.data()))
            .toList());
  }
}
