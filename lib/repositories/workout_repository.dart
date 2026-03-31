import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workout.dart';
import '../providers/auth_provider.dart';

/// Firestore CRUD for workouts — offline-first sync
/// Collection: workouts/{workoutId}  (with uid field for queries)
class WorkoutRepository {
  final FirebaseFirestore _db;

  WorkoutRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _workouts =>
      _db.collection('workouts');

  /// Save workout to Firestore
  Future<void> saveWorkout(String uid, Workout workout) async {
    await _workouts.doc(workout.id).set({
      ...workout.toJson(),
      'uid': uid,
      'syncedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get all workouts for a user (most recent first)
  Future<List<Workout>> getWorkouts(String uid) async {
    final snapshot = await _workouts
        .where('uid', isEqualTo: uid)
        .orderBy('startTime', descending: true)
        .limit(100)
        .get();

    return snapshot.docs
        .map((doc) => Workout.fromJson(doc.data()))
        .toList();
  }

  /// Delete a workout
  Future<void> deleteWorkout(String workoutId) async {
    await _workouts.doc(workoutId).delete();
  }

  /// Sync local workouts to Firestore (first login migration)
  Future<int> syncLocalWorkouts(String uid, List<Workout> localWorkouts) async {
    final batch = _db.batch();
    int count = 0;

    for (final workout in localWorkouts) {
      // Check if already synced
      final existing = await _workouts.doc(workout.id).get();
      if (!existing.exists) {
        batch.set(_workouts.doc(workout.id), {
          ...workout.toJson(),
          'uid': uid,
          'syncedAt': FieldValue.serverTimestamp(),
        });
        count++;
      }
    }

    if (count > 0) await batch.commit();
    return count;
  }

  /// Real-time stream of user's workouts
  Stream<List<Workout>> workoutStream(String uid) {
    return _workouts
        .where('uid', isEqualTo: uid)
        .orderBy('startTime', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Workout.fromJson(doc.data())).toList());
  }
}

/// Provider for WorkoutRepository
final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository(FirebaseFirestore.instance);
});

/// Stream of current user's Firestore workouts
final firestoreWorkoutsProvider = StreamProvider<List<Workout>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(workoutRepositoryProvider).workoutStream(user.uid);
});
