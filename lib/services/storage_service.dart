import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/group_session.dart';
import '../models/user_profile.dart';
import '../models/workout.dart';

/// Local storage service for user profile and workout history
class StorageService {
  static const _profileKey = 'user_profile';
  static const _workoutsKey = 'workouts';
  static const _groupSessionsKey = 'group_sessions';

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

  /// Update a workout in place (e.g., add notes/RPE after save) (7.3/7.4)
  static Future<void> updateWorkout(Workout updated) async {
    final workouts = await loadWorkouts();
    final idx = workouts.indexWhere((w) => w.id == updated.id);
    if (idx >= 0) {
      workouts[idx] = updated;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _workoutsKey,
        jsonEncode(workouts.map((w) => w.toJson()).toList()),
      );
    }
  }

  /// Get workout count
  static Future<int> workoutCount() async {
    final workouts = await loadWorkouts();
    return workouts.length;
  }

  // ═══════════════════════════════════════════
  // LAST CONNECTED DEVICE (for auto-reconnect)
  // ═══════════════════════════════════════════

  static const _lastDeviceIdKey = 'last_device_id';
  static const _lastDeviceNameKey = 'last_device_name';

  /// Save last connected device info
  static Future<void> saveLastDevice(String deviceId, String deviceName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastDeviceIdKey, deviceId);
    await prefs.setString(_lastDeviceNameKey, deviceName);
  }

  /// Load last connected device info
  static Future<({String? id, String? name})> loadLastDevice() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      id: prefs.getString(_lastDeviceIdKey),
      name: prefs.getString(_lastDeviceNameKey),
    );
  }

  /// Clear last device (after manual disconnect)
  static Future<void> clearLastDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastDeviceIdKey);
    await prefs.remove(_lastDeviceNameKey);
  }

  // ═══════════════════════════════════════════
  // PERSONAL RECORDS
  // ═══════════════════════════════════════════

  /// Check if a workout contains any personal records
  /// Returns a list of PR label strings (empty = no PRs)
  static Future<List<String>> checkPersonalRecords(Workout newWorkout) async {
    final all = await loadWorkouts();
    // Exclude the new workout from comparison (it's already saved)
    final previous = all.where((w) => w.id != newWorkout.id).toList();
    if (previous.isEmpty) return ['First Workout!']; // First ever session = PR

    final prs = <String>[];
    final a = newWorkout.analytics;
    final d = newWorkout.duration;

    // Longest duration
    final longestPrev = previous.map((w) => w.duration.inSeconds).reduce((a, b) => a > b ? a : b);
    if (d.inSeconds > longestPrev) prs.add('🏆 Longest Session');

    // Most calories
    final mostCalPrev = previous.map((w) => w.analytics.calories).reduce((a, b) => a > b ? a : b);
    if (a.calories > mostCalPrev) prs.add('🔥 Most Calories');

    // Highest TRIMP
    final mostTrimpPrev = previous.map((w) => w.analytics.trimp).reduce((a, b) => a > b ? a : b);
    if (a.trimp > mostTrimpPrev) prs.add('⚡ Highest Load');

    // Best Training Effect
    final bestTePrev = previous.map((w) => w.analytics.trainingEffect).reduce((a, b) => a > b ? a : b);
    if (a.trainingEffect > bestTePrev) prs.add('📈 Best Training Effect');

    return prs;
  }

  // ═══════════════════════════════════════════
  // WEEKLY STATS & STREAK
  // ═══════════════════════════════════════════

  /// Returns workouts from the last 7 days
  static Future<List<Workout>> loadWeeklyWorkouts() async {
    final all = await loadWorkouts();
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return all.where((w) => w.startTime.isAfter(cutoff)).toList();
  }

  /// Calculate current consecutive-day workout streak
  static Future<int> calculateStreak() async {
    final all = await loadWorkouts();
    if (all.isEmpty) return 0;

    // Get unique workout dates (local date, no time)
    final dates = all
        .map((w) => DateTime(w.startTime.year, w.startTime.month, w.startTime.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a)); // desc

    int streak = 0;
    DateTime cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);

    for (final date in dates) {
      final diff = cursor.difference(date).inDays;
      if (diff == 0 || diff == 1) {
        streak++;
        cursor = date;
      } else {
        break;
      }
    }
    return streak;
  }

  /// Weekly summary: total time, calories, sessions
  static Future<({int sessions, int minutes, int calories, int trimp})> weeklyStats() async {
    final week = await loadWeeklyWorkouts();
    return (
      sessions: week.length,
      minutes: week.fold(0, (sum, w) => sum + w.duration.inMinutes),
      calories: week.fold(0, (sum, w) => sum + w.analytics.calories.round()),
      trimp: week.fold(0, (sum, w) => sum + w.analytics.trimp.round()),
    );
  }

  // ═══════════════════════════════════════════
  // 5.4 GROUP SESSION HISTORY
  // ═══════════════════════════════════════════

  /// Save a completed group session
  static Future<void> saveGroupSession(GroupSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await loadGroupSessions();
    sessions.insert(0, session);
    if (sessions.length > 50) sessions.removeRange(50, sessions.length);
    await prefs.setString(
      _groupSessionsKey,
      jsonEncode(sessions.map((s) => s.toJson()).toList()),
    );
  }

  /// Load all group sessions (most recent first)
  static Future<List<GroupSession>> loadGroupSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_groupSessionsKey);
    if (json == null) return [];
    try {
      final list = jsonDecode(json) as List;
      return list
          .map((s) => GroupSession.fromJson(s as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Delete a group session by ID
  static Future<void> deleteGroupSession(String sessionId) async {
    final sessions = await loadGroupSessions();
    sessions.removeWhere((s) => s.id == sessionId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _groupSessionsKey,
      jsonEncode(sessions.map((s) => s.toJson()).toList()),
    );
  }

  // ═══════════════════════════════════════════
  // 11.5 DATA BACKUP & RESTORE
  // ═══════════════════════════════════════════

  /// Export all data as a JSON string for backup
  static Future<String> exportBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final backup = <String, dynamic>{
      'version': 1,
      'profile': prefs.getString(_profileKey),
      'workouts': prefs.getString(_workoutsKey),
      'group_sessions': prefs.getString(_groupSessionsKey),
      'last_device_id': prefs.getString(_lastDeviceIdKey),
      'last_device_name': prefs.getString(_lastDeviceNameKey),
      'exported_at': DateTime.now().toIso8601String(),
    };
    return jsonEncode(backup);
  }

  /// Import data from a backup JSON string
  static Future<bool> importBackup(String json) async {
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      if (data['profile'] != null) {
        await prefs.setString(_profileKey, data['profile'] as String);
      }
      if (data['workouts'] != null) {
        await prefs.setString(_workoutsKey, data['workouts'] as String);
      }
      if (data['group_sessions'] != null) {
        await prefs.setString(_groupSessionsKey, data['group_sessions'] as String);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ═══════════════════════════════════════════
  // 11.6 PROFILE RESET
  // ═══════════════════════════════════════════

  /// Clear all stored data (factory reset)
  static Future<void> resetAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
