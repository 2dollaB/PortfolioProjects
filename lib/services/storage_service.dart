import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/workout.dart';

/// Local storage service for user profile and workout history
class StorageService {
  static const _profileKey = 'user_profile';
  static const _workoutsKey = 'workouts';

  // ═══════════════════════════════════════════
  // USER PROFILE
  // ═══════════════════════════════════════════

  /// Save user profile locally
  static Future<void> saveProfile(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  /// Load user profile (returns null if not set up yet)
  static Future<UserProfile?> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_profileKey);
    if (json == null) return null;
    try {
      return UserProfile.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Check if user has completed profile setup
  static Future<bool> hasProfile() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_profileKey);
  }

  // ═══════════════════════════════════════════
  // WORKOUT HISTORY
  // ═══════════════════════════════════════════

  /// Save a completed workout
  static Future<void> saveWorkout(Workout workout) async {
    final prefs = await SharedPreferences.getInstance();
    final workouts = await loadWorkouts();
    workouts.insert(0, workout); // Most recent first

    // Keep max 100 workouts locally
    if (workouts.length > 100) {
      workouts.removeRange(100, workouts.length);
    }

    final jsonList = workouts.map((w) => w.toJson()).toList();
    await prefs.setString(_workoutsKey, jsonEncode(jsonList));
  }

  /// Load all saved workouts (most recent first)
  static Future<List<Workout>> loadWorkouts() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_workoutsKey);
    if (json == null) return [];

    try {
      final list = jsonDecode(json) as List;
      return list
          .map((w) => Workout.fromJson(w as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Delete a workout by ID
  static Future<void> deleteWorkout(String workoutId) async {
    final workouts = await loadWorkouts();
    workouts.removeWhere((w) => w.id == workoutId);
    final prefs = await SharedPreferences.getInstance();
    final jsonList = workouts.map((w) => w.toJson()).toList();
    await prefs.setString(_workoutsKey, jsonEncode(jsonList));
  }

  /// Get workout count
  static Future<int> workoutCount() async {
    final workouts = await loadWorkouts();
    return workouts.length;
  }
}
