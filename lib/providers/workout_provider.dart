import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workout.dart';
import '../models/group_session.dart';
import '../services/storage_service.dart';

/// Workout history state
class WorkoutHistoryNotifier extends AsyncNotifier<List<Workout>> {
  @override
  Future<List<Workout>> build() async {
    return StorageService.loadWorkouts();
  }

  /// Add a completed workout
  Future<void> addWorkout(Workout workout) async {
    await StorageService.saveWorkout(workout);
    state = AsyncData(await StorageService.loadWorkouts());
  }

  /// Update a workout (notes, RPE, mood)
  Future<void> updateWorkout(Workout updated) async {
    await StorageService.updateWorkout(updated);
    state = AsyncData(await StorageService.loadWorkouts());
  }

  /// Delete a workout
  Future<void> deleteWorkout(String workoutId) async {
    await StorageService.deleteWorkout(workoutId);
    state = AsyncData(await StorageService.loadWorkouts());
  }
}

final workoutHistoryProvider =
    AsyncNotifierProvider<WorkoutHistoryNotifier, List<Workout>>(
  WorkoutHistoryNotifier.new,
);

/// Group session history
class GroupSessionHistoryNotifier extends AsyncNotifier<List<GroupSession>> {
  @override
  Future<List<GroupSession>> build() async {
    return StorageService.loadGroupSessions();
  }

  Future<void> addSession(GroupSession session) async {
    await StorageService.saveGroupSession(session);
    state = AsyncData(await StorageService.loadGroupSessions());
  }

  Future<void> deleteSession(String sessionId) async {
    await StorageService.deleteGroupSession(sessionId);
    state = AsyncData(await StorageService.loadGroupSessions());
  }
}

final groupSessionHistoryProvider =
    AsyncNotifierProvider<GroupSessionHistoryNotifier, List<GroupSession>>(
  GroupSessionHistoryNotifier.new,
);

/// Derived: weekly stats
final weeklyStatsProvider =
    FutureProvider<({int sessions, int minutes, int calories, int trimp})>(
  (ref) async {
    // Re-compute when workout history changes
    ref.watch(workoutHistoryProvider);
    return StorageService.weeklyStats();
  },
);

/// Derived: workout streak
final streakProvider = FutureProvider<int>((ref) async {
  ref.watch(workoutHistoryProvider);
  return StorageService.calculateStreak();
});

/// Derived: personal records check for a specific workout
final personalRecordsProvider =
    FutureProvider.family<List<String>, Workout>((ref, workout) async {
  return StorageService.checkPersonalRecords(workout);
});
