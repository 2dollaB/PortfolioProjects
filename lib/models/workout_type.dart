import 'package:flutter/material.dart';

/// Workout type for categorizing sessions
enum WorkoutType {
  free,
  hiit,
  cardio,
  strength,
  cycling,
  yoga;

  String get displayName {
    switch (this) {
      case WorkoutType.free:
        return 'Free';
      case WorkoutType.hiit:
        return 'HIIT';
      case WorkoutType.cardio:
        return 'Cardio';
      case WorkoutType.strength:
        return 'Strength';
      case WorkoutType.cycling:
        return 'Cycling';
      case WorkoutType.yoga:
        return 'Yoga';
    }
  }

  String get description {
    switch (this) {
      case WorkoutType.free:
        return 'Unrestricted, all-purpose tracking';
      case WorkoutType.hiit:
        return 'High-intensity intervals with laps';
      case WorkoutType.cardio:
        return 'Sustained aerobic effort';
      case WorkoutType.strength:
        return 'Weight training & resistance';
      case WorkoutType.cycling:
        return 'Indoor or outdoor cycling';
      case WorkoutType.yoga:
        return 'Mindful movement & recovery';
    }
  }

  IconData get icon {
    switch (this) {
      case WorkoutType.free:
        return Icons.sports_rounded;
      case WorkoutType.hiit:
        return Icons.flash_on_rounded;
      case WorkoutType.cardio:
        return Icons.directions_run_rounded;
      case WorkoutType.strength:
        return Icons.fitness_center_rounded;
      case WorkoutType.cycling:
        return Icons.directions_bike_rounded;
      case WorkoutType.yoga:
        return Icons.self_improvement_rounded;
    }
  }

  /// Whether this type benefits from lap markers
  bool get hasLaps => this == WorkoutType.hiit;

  /// Whether this type benefits from interval timer (7.1)
  bool get hasIntervals => this == WorkoutType.hiit;
}
