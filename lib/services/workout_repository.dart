import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/workout_summary.dart';

/// Writes/reads the `workouts` collection. Each doc is owned by one user
/// (`userId` == owner uid); the schema stores summary fields, not raw HR
/// samples.
class WorkoutRepository {
  WorkoutRepository._();

  static final CollectionReference<Map<String, dynamic>> _workouts =
      FirebaseFirestore.instance.collection('workouts');

  /// Persists a completed workout's summary; returns the new doc id.
  /// [sessionId] links the workout to the cloud group session it was part of.
  static Future<String> save({
    required String userId,
    required String type,
    required DateTime startTime,
    required DateTime endTime,
    required int avgHr,
    required int maxHr,
    required int calories,
    required int trimp,
    required int beatPoints,
    required List<int> zoneDist,
    required int dominantZone,
    String? sessionId,
  }) async {
    final ref = await _workouts.add({
      'userId': userId,
      'type': type,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'avgHr': avgHr,
      'maxHr': maxHr,
      'calories': calories,
      'trimp': trimp,
      'beatPoints': beatPoints,
      'zoneDist': zoneDist,
      'dominantZone': dominantZone,
      'sessionId': ?sessionId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// One-shot variant of [watchRecent] — used for cross-member aggregations
  /// (studio analytics) where N live streams would be wasteful.
  static Future<List<WorkoutSummary>> fetchRecent(String uid,
      {int limit = 50}) async {
    final snap = await _workouts
        .where('userId', isEqualTo: uid)
        .orderBy('startTime', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => WorkoutSummary.fromDoc(d.id, d.data()))
        .toList();
  }

  /// All athletes' workouts recorded in one cloud group session (rules allow
  /// this cross-user query for the session's host). Plain equality filter —
  /// no composite index needed; callers sort the handful of results.
  static Future<List<WorkoutSummary>> fetchBySession(String sessionId) async {
    final snap = await _workouts.where('sessionId', isEqualTo: sessionId).get();
    return snap.docs
        .map((d) => WorkoutSummary.fromDoc(d.id, d.data()))
        .toList();
  }

  /// Streams a user's workouts, most recent first (uses the userId+startTime
  /// composite index).
  static Stream<List<WorkoutSummary>> watchRecent(String uid, {int limit = 50}) {
    return _workouts
        .where('userId', isEqualTo: uid)
        .orderBy('startTime', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => WorkoutSummary.fromDoc(d.id, d.data()))
            .toList());
  }
}
