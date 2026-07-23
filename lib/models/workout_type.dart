import 'package:flutter/material.dart';

/// Workout type for categorizing sessions. Each type carries a fixed MET
/// constant used by the calorie model (see AnalyticsEngine).
enum WorkoutType {
  strength,
  cardio,
  hiit,
  crossfit,
  free;

  String get displayName {
    switch (this) {
      case WorkoutType.strength:
        return 'Strength';
      case WorkoutType.cardio:
        return 'Cardio';
      case WorkoutType.hiit:
        return 'HIIT';
      case WorkoutType.crossfit:
        return 'CrossFit';
      case WorkoutType.free:
        return 'Custom';
    }
  }

  String get description {
    switch (this) {
      case WorkoutType.strength:
        return 'Weight training & resistance';
      case WorkoutType.cardio:
        return 'Sustained aerobic effort';
      case WorkoutType.hiit:
        return 'High-intensity intervals with laps';
      case WorkoutType.crossfit:
        return 'Functional, mixed-modal conditioning';
      case WorkoutType.free:
        return 'Unrestricted, all-purpose tracking';
    }
  }

  IconData get icon {
    switch (this) {
      case WorkoutType.strength:
        return Icons.fitness_center_rounded;
      case WorkoutType.cardio:
        return Icons.directions_run_rounded;
      case WorkoutType.hiit:
        return Icons.flash_on_rounded;
      case WorkoutType.crossfit:
        return Icons.sports_gymnastics_rounded;
      case WorkoutType.free:
        return Icons.sports_rounded;
    }
  }

  /// Fixed MET constant per type — energy cost multiplier for the calorie model.
  double get met {
    switch (this) {
      case WorkoutType.cardio:
        return 6.0;
      case WorkoutType.strength:
        return 8.0;
      case WorkoutType.hiit:
        return 9.0;
      case WorkoutType.crossfit:
        return 10.0;
      case WorkoutType.free:
        return 7.0;
    }
  }

  /// Parse a stored value, falling back to [free] for legacy/unknown types
  /// (e.g. old `cycling`/`yoga` workouts saved before this set existed).
  static WorkoutType fromName(String? name) => WorkoutType.values.firstWhere(
        (e) => e.name == name,
        orElse: () => WorkoutType.free,
      );

  /// Whether this type benefits from lap markers
  bool get hasLaps => this == WorkoutType.hiit;

  /// Whether this type benefits from interval timer (7.1)
  bool get hasIntervals => this == WorkoutType.hiit;
}
