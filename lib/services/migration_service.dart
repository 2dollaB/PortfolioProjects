import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/user_repository.dart';
import '../repositories/workout_repository.dart';
import 'storage_service.dart';

/// Migrates SharedPreferences data to Firestore on first login
class MigrationService {
  static const _migratedKey = 'data_migrated_to_firestore';

  final UserRepository _userRepo;
  final WorkoutRepository _workoutRepo;

  MigrationService(this._userRepo, this._workoutRepo);

  /// Check if migration is needed and run it
  Future<void> migrateIfNeeded(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migratedKey) == true) return;

    debugPrint('[BeatSync] Starting data migration to Firestore...');

    try {
      // Migrate profile
      final profile = await StorageService.loadProfile();
      if (profile != null) {
        await _userRepo.saveProfile(uid, profile);
        debugPrint('[BeatSync] Profile migrated');
      }

      // Migrate workouts
      final workouts = await StorageService.loadWorkouts();
      if (workouts.isNotEmpty) {
        final count = await _workoutRepo.syncLocalWorkouts(uid, workouts);
        debugPrint('[BeatSync] $count workouts migrated');
      }

      // Mark as done
      await prefs.setBool(_migratedKey, true);
      debugPrint('[BeatSync] Migration complete');
    } catch (e) {
      debugPrint('[BeatSync] Migration error: $e');
      // Don't mark as migrated — will retry next time
    }
  }
}
