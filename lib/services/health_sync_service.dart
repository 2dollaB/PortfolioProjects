import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import '../models/workout.dart';

/// 6.3 — Health sync service
/// Writes completed workouts to Apple Health (iOS) or Google Health Connect (Android).
/// Read-only access to steps and resting HR is also supported.
class HealthSyncService {
  static final _health = Health();
  static bool _permissionsGranted = false;

  static final _writeTypes = <HealthDataType>[
    HealthDataType.WORKOUT,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  static final _readTypes = <HealthDataType>[
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  // ══════════════════════════════════════════════
  // Permissions
  // ══════════════════════════════════════════════

  static Future<bool> requestPermissions() async {
    if (!Platform.isIOS && !Platform.isAndroid) return false;
    try {
      _health.configure();
      final granted = await _health.requestAuthorization(
        _readTypes + _writeTypes,
      );
      _permissionsGranted = granted;
      debugPrint('[Health] Permissions granted: $granted');
      return granted;
    } catch (e) {
      debugPrint('[Health] Permission error: $e');
      return false;
    }
  }

  static Future<bool> hasPermissions() async {
    if (!Platform.isIOS && !Platform.isAndroid) return false;
    try {
      _health.configure();
      final ok = await _health.hasPermissions(_writeTypes);
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  // ══════════════════════════════════════════════
  // Write workout to Health
  // ══════════════════════════════════════════════

  /// Sync a completed workout to Apple Health / Google Health Connect
  static Future<HealthSyncResult> syncWorkout(Workout workout) async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return HealthSyncResult.notSupported;
    }

    if (!_permissionsGranted) {
      final granted = await requestPermissions();
      if (!granted) return HealthSyncResult.permissionDenied;
    }

    try {
      final start = workout.startTime;
      final end   = start.add(workout.duration);
      final a     = workout.analytics;

      // Write workout session
      await _health.writeWorkoutData(
        activityType: _mapWorkoutType(workout),
        start: start,
        end: end,
        totalEnergyBurned: a.calories.round(),
        totalEnergyBurnedUnit: HealthDataUnit.KILOCALORIE,
      );

      // Write calories separately for Health Connect compatibility
      await _health.writeHealthData(
        value: a.calories,
        type: HealthDataType.ACTIVE_ENERGY_BURNED,
        startTime: start,
        endTime: end,
        unit: HealthDataUnit.KILOCALORIE,
      );

      // Write average HR point
      if (a.avgHr > 0) {
        final mid = start.add(workout.duration ~/ 2);
        await _health.writeHealthData(
          value: a.avgHr.toDouble(),
          type: HealthDataType.HEART_RATE,
          startTime: mid,
          endTime: mid.add(const Duration(seconds: 1)),
          unit: HealthDataUnit.BEATS_PER_MINUTE,
        );
      }

      debugPrint('[Health] Workout synced: ${workout.id}');
      return HealthSyncResult.success;
    } catch (e) {
      debugPrint('[Health] Sync error: $e');
      return HealthSyncResult.error;
    }
  }

  // ══════════════════════════════════════════════
  // Read from Health
  // ══════════════════════════════════════════════

  /// Read resting HR from Apple Health / Google Health Connect (last 7 days)
  static Future<double?> readRestingHr() async {
    if (!Platform.isIOS && !Platform.isAndroid) return null;
    try {
      final now = DateTime.now();
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.RESTING_HEART_RATE],
        startTime: now.subtract(const Duration(days: 7)),
        endTime: now,
      );
      if (data.isEmpty) return null;
      final latest = data.last;
      final val    = latest.value;
      if (val is NumericHealthValue) return val.numericValue.toDouble();
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Read steps today
  static Future<int> readStepsToday() async {
    if (!Platform.isIOS && !Platform.isAndroid) return 0;
    try {
      final now   = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final steps = await _health.getTotalStepsInInterval(start, now);
      return steps ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // ══════════════════════════════════════════════
  // Helpers
  // ══════════════════════════════════════════════

  static HealthWorkoutActivityType _mapWorkoutType(Workout w) {
    switch (w.workoutType.name) {
      case 'hiit':       return HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING;
      case 'crossfit':   return HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING;
      case 'strength':   return HealthWorkoutActivityType.STRENGTH_TRAINING;
      case 'cardio':
      default:           return HealthWorkoutActivityType.CARDIO_DANCE;
    }
  }
}

enum HealthSyncResult {
  success,
  permissionDenied,
  notSupported,
  error;

  bool get ok => this == HealthSyncResult.success;

  String get message {
    switch (this) {
      case success:         return 'Synced to Health ✓';
      case permissionDenied: return 'Health access denied';
      case notSupported:    return 'Not supported on this platform';
      case error:           return 'Sync failed — try again';
    }
  }
}
