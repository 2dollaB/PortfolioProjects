import 'package:cloud_firestore/cloud_firestore.dart';

/// Writes/reads the `workouts` collection. Each doc is owned by one user
/// (`userId` == owner uid); the schema stores summary fields, not raw HR
/// samples. Display/read APIs arrive in Part 2.
class WorkoutRepository {
  WorkoutRepository._();

  static final CollectionReference<Map<String, dynamic>> _workouts =
      FirebaseFirestore.instance.collection('workouts');

  /// Persists a completed workout's summary; returns the new doc id.
  /// (`sessionId` linkage arrives with cloud sessions.)
  static Future<String> save({
    required String userId,
    required String type,
    required DateTime startTime,
    required DateTime endTime,
    required int avgHr,
    required int maxHr,
    required int calories,
    required int trimp,
    required List<int> zoneDist,
    required int dominantZone,
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
      'zoneDist': zoneDist,
      'dominantZone': dominantZone,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }
}
