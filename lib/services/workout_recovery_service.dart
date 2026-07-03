import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'workout_repository.dart';

/// Crash-safety net for in-progress workouts: the workout screen snapshots
/// its running totals every few seconds; if the process dies mid-workout,
/// the next launch saves the snapshot to history instead of losing it.
class WorkoutRecoveryService {
  WorkoutRecoveryService._();

  static const _key = 'workout_recovery';

  /// Snapshots shorter than this are treated as accidental starts.
  static const _minDuration = Duration(minutes: 1);

  static Future<void> snapshot(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(payload));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Saves a leftover snapshot as a finished workout. Returns true when one
  /// was recovered so the caller can tell the user. Always clears the
  /// snapshot, so a malformed one can't loop forever.
  static Future<bool> recover(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return false;
    await prefs.remove(_key);
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (m['userId'] != uid) return false;
      final start = DateTime.fromMillisecondsSinceEpoch(m['startMs'] as int);
      final end = DateTime.fromMillisecondsSinceEpoch(m['lastMs'] as int);
      if (end.difference(start) < _minDuration) return false;
      await WorkoutRepository.save(
        userId: uid,
        type: m['type'] as String,
        startTime: start,
        endTime: end,
        avgHr: m['avgHr'] as int,
        maxHr: m['maxHr'] as int,
        calories: m['calories'] as int,
        trimp: m['trimp'] as int,
        zoneDist: (m['zoneDist'] as List).cast<int>(),
        dominantZone: m['dominantZone'] as int,
        sessionId: m['sessionId'] as String?,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
