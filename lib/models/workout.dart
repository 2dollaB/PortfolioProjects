import 'dart:math' as math;
import 'user_profile.dart';
import 'workout_type.dart';

/// A single recorded HR data point during a workout
class HrDataPoint {
  final int bpm;
  final int zone;
  final DateTime timestamp;
  final List<int> rrIntervals; // milliseconds (8.4 HRV)

  const HrDataPoint({
    required this.bpm,
    required this.zone,
    required this.timestamp,
    this.rrIntervals = const [],
  });

  Map<String, dynamic> toJson() => {
        'bpm': bpm,
        'zone': zone,
        'timestamp': timestamp.toIso8601String(),
        if (rrIntervals.isNotEmpty) 'rrIntervals': rrIntervals,
      };

  factory HrDataPoint.fromJson(Map<String, dynamic> json) => HrDataPoint(
        bpm: json['bpm'] as int,
        zone: json['zone'] as int,
        timestamp: DateTime.parse(json['timestamp'] as String),
        rrIntervals: (json['rrIntervals'] as List?)
            ?.map((e) => e as int)
            .toList() ?? const [],
      );
}

/// Complete workout session with analytics
class Workout {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final List<HrDataPoint> dataPoints;
  final WorkoutAnalytics analytics;
  final WorkoutType workoutType;
  final List<Duration> lapMarkers;
  final String? notes;
  final int? rpe;        // 1-10 perceived exertion
  final String? moodEmoji; // e.g. '😊'

  const Workout({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.dataPoints,
    required this.analytics,
    this.workoutType = WorkoutType.free,
    this.lapMarkers = const [],
    this.notes,
    this.rpe,
    this.moodEmoji,
  });

  Duration get duration => endTime.difference(startTime);

  /// Create a copy with optional field overrides (7.3/7.4)
  Workout copyWith({String? notes, int? rpe, String? moodEmoji}) => Workout(
    id: id,
    startTime: startTime,
    endTime: endTime,
    dataPoints: dataPoints,
    analytics: analytics,
    workoutType: workoutType,
    lapMarkers: lapMarkers,
    notes: notes ?? this.notes,
    rpe: rpe ?? this.rpe,
    moodEmoji: moodEmoji ?? this.moodEmoji,
  );

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'dataPoints': dataPoints.map((d) => d.toJson()).toList(),
        'analytics': analytics.toJson(),
        'workoutType': workoutType.name,
        'lapMarkers': lapMarkers.map((d) => d.inSeconds).toList(),
        'notes': notes,
        'rpe': rpe,
        'moodEmoji': moodEmoji,
      };

  factory Workout.fromJson(Map<String, dynamic> json) => Workout(
        id: json['id'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: DateTime.parse(json['endTime'] as String),
        dataPoints: (json['dataPoints'] as List)
            .map((d) => HrDataPoint.fromJson(d as Map<String, dynamic>))
            .toList(),
        analytics:
            WorkoutAnalytics.fromJson(json['analytics'] as Map<String, dynamic>),
        workoutType: WorkoutType.values.firstWhere(
          (e) => e.name == json['workoutType'],
          orElse: () => WorkoutType.free,
        ),
        lapMarkers: (json['lapMarkers'] as List? ?? [])
            .map((s) => Duration(seconds: s as int))
            .toList(),
        notes: json['notes'] as String?,
        rpe: json['rpe'] as int?,
        moodEmoji: json['moodEmoji'] as String?,
      );
}

/// Post-workout calculated analytics
class WorkoutAnalytics {
  final int avgHr;
  final int maxHr;
  final int minHr;
  final double calories;
  final double trimp;
  final double trainingEffect;
  final int hrRecovery; // BPM drop in 60s after workout
  final Map<int, Duration> timeInZone; // zone → duration
  final int hrMax; // HRmax used for this workout

  const WorkoutAnalytics({
    required this.avgHr,
    required this.maxHr,
    required this.minHr,
    required this.calories,
    required this.trimp,
    required this.trainingEffect,
    required this.hrRecovery,
    required this.timeInZone,
    required this.hrMax,
  });

  /// Percentage of total workout time in each zone
  Map<int, double> zonePercentages(Duration totalDuration) {
    final totalSeconds = totalDuration.inSeconds;
    if (totalSeconds == 0) return {};
    return timeInZone.map(
      (zone, duration) => MapEntry(zone, duration.inSeconds / totalSeconds * 100),
    );
  }

  /// Training Effect label
  String get trainingEffectLabel {
    if (trainingEffect < 1.0) return 'Minor';
    if (trainingEffect < 2.0) return 'Maintaining';
    if (trainingEffect < 3.0) return 'Improving';
    if (trainingEffect < 4.0) return 'Highly Improving';
    if (trainingEffect < 5.0) return 'Overreaching';
    return 'Overreaching';
  }

  Map<String, dynamic> toJson() => {
        'avgHr': avgHr,
        'maxHr': maxHr,
        'minHr': minHr,
        'calories': calories,
        'trimp': trimp,
        'trainingEffect': trainingEffect,
        'hrRecovery': hrRecovery,
        'hrMax': hrMax,
        'timeInZone':
            timeInZone.map((k, v) => MapEntry(k.toString(), v.inSeconds)),
      };

  factory WorkoutAnalytics.fromJson(Map<String, dynamic> json) =>
      WorkoutAnalytics(
        avgHr: json['avgHr'] as int,
        maxHr: json['maxHr'] as int,
        minHr: json['minHr'] as int,
        calories: (json['calories'] as num).toDouble(),
        trimp: (json['trimp'] as num).toDouble(),
        trainingEffect: (json['trainingEffect'] as num).toDouble(),
        hrRecovery: json['hrRecovery'] as int,
        hrMax: json['hrMax'] as int,
        timeInZone: (json['timeInZone'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(int.parse(k), Duration(seconds: v as int)),
        ),
      );
}

/// Analytics calculator — all science-backed formulas
class AnalyticsEngine {
  /// Calculate full post-workout analytics
  static WorkoutAnalytics calculate({
    required List<HrDataPoint> dataPoints,
    required UserProfile profile,
    required Duration totalDuration,
    int hrRecoveryBpm = 0,
  }) {
    if (dataPoints.isEmpty) {
      return WorkoutAnalytics(
        avgHr: 0,
        maxHr: 0,
        minHr: 0,
        calories: 0,
        trimp: 0,
        trainingEffect: 0,
        hrRecovery: 0,
        timeInZone: {},
        hrMax: profile.hrMax,
      );
    }

    // Basic stats
    final bpms = dataPoints.map((d) => d.bpm).toList();
    final avgHr = (bpms.reduce((a, b) => a + b) / bpms.length).round();
    final maxHr = bpms.reduce(math.max);
    final minHr = bpms.reduce(math.min);

    // Time in zones
    final timeInZone = _calculateTimeInZones(dataPoints);

    // Calories — Keytel formula (2005)
    final calories = _calculateCalories(
      avgHr: avgHr,
      durationMinutes: totalDuration.inSeconds / 60,
      weightKg: profile.weightKg,
      sex: profile.sex,
      age: profile.age,
    );

    // TRIMP — Bannister exponential model
    final trimp = _calculateTrimp(
      dataPoints: dataPoints,
      hrMax: profile.hrMax,
      restingHr: profile.restingHr ?? 60,
      genderFactor: profile.trimpGenderFactor,
    );

    // Training Effect — estimated from TRIMP
    final trainingEffect = _calculateTrainingEffect(
      trimp: trimp,
      fitnessMultiplier: profile.fitnessMultiplier,
    );

    return WorkoutAnalytics(
      avgHr: avgHr,
      maxHr: maxHr,
      minHr: minHr,
      calories: calories,
      trimp: trimp,
      trainingEffect: trainingEffect,
      hrRecovery: hrRecoveryBpm,
      timeInZone: timeInZone,
      hrMax: profile.hrMax,
    );
  }

  /// Time spent in each zone
  static Map<int, Duration> _calculateTimeInZones(List<HrDataPoint> dataPoints) {
    final timeInZone = <int, int>{}; // zone → seconds

    for (int i = 0; i < dataPoints.length - 1; i++) {
      final zone = dataPoints[i].zone;
      final seconds =
          dataPoints[i + 1].timestamp.difference(dataPoints[i].timestamp).inSeconds;
      timeInZone[zone] = (timeInZone[zone] ?? 0) + seconds;
    }

    // Add last point with 1 second
    if (dataPoints.isNotEmpty) {
      final lastZone = dataPoints.last.zone;
      timeInZone[lastZone] = (timeInZone[lastZone] ?? 0) + 1;
    }

    return timeInZone.map((k, v) => MapEntry(k, Duration(seconds: v)));
  }

  /// Keytel Calorie Formula (2005)
  /// Male:   kcal/min = (-55.0969 + 0.6309×HR + 0.1988×weight + 0.2017×age) / 4.184
  /// Female: kcal/min = (-20.4022 + 0.4472×HR - 0.1263×weight + 0.074×age) / 4.184
  static double _calculateCalories({
    required int avgHr,
    required double durationMinutes,
    required double weightKg,
    required Sex sex,
    required int age,
  }) {
    double kcalPerMin;
    switch (sex) {
      case Sex.female:
        kcalPerMin =
            (-20.4022 + 0.4472 * avgHr - 0.1263 * weightKg + 0.074 * age) /
                4.184;
        break;
      case Sex.male:
      case Sex.other:
        kcalPerMin =
            (-55.0969 + 0.6309 * avgHr + 0.1988 * weightKg + 0.2017 * age) /
                4.184;
        break;
    }
    return math.max(0, kcalPerMin * durationMinutes);
  }

  /// Bannister TRIMP (Training Impulse)
  /// TRIMP = Σ (duration_i × ΔHR_ratio × 0.64 × e^(gender_factor × ΔHR_ratio))
  ///
  /// Where ΔHR_ratio = (HR - HRrest) / (HRmax - HRrest)
  static double _calculateTrimp({
    required List<HrDataPoint> dataPoints,
    required int hrMax,
    required int restingHr,
    required double genderFactor,
  }) {
    double trimp = 0;
    final hrRange = hrMax - restingHr;
    if (hrRange <= 0) return 0;

    for (int i = 0; i < dataPoints.length - 1; i++) {
      final durationMin = dataPoints[i + 1]
              .timestamp
              .difference(dataPoints[i].timestamp)
              .inSeconds /
          60;
      final hrReserve = (dataPoints[i].bpm - restingHr) / hrRange;
      final clampedReserve = hrReserve.clamp(0.0, 1.0);

      trimp += durationMin *
          clampedReserve *
          0.64 *
          math.exp(genderFactor * clampedReserve);
    }

    return trimp;
  }

  /// Training Effect estimation from TRIMP
  /// Scale: 1.0 (Minor) → 5.0 (Overreaching)
  /// Based on Firstbeat model approximation
  static double _calculateTrainingEffect({
    required double trimp,
    required double fitnessMultiplier,
  }) {
    // Adjusted TRIMP based on fitness level
    final adjustedTrimp = trimp * fitnessMultiplier;

    // Map TRIMP to 1-5 Training Effect scale
    // Typical 30-min moderate workout = TRIMP ~50-80
    // Typical 60-min intense workout = TRIMP ~150-250
    if (adjustedTrimp < 10) return 0.5;
    if (adjustedTrimp < 30) return 1.0 + (adjustedTrimp - 10) / 20 * 0.5;
    if (adjustedTrimp < 60) return 1.5 + (adjustedTrimp - 30) / 30 * 0.5;
    if (adjustedTrimp < 100) return 2.0 + (adjustedTrimp - 60) / 40 * 1.0;
    if (adjustedTrimp < 180) return 3.0 + (adjustedTrimp - 100) / 80 * 1.0;
    if (adjustedTrimp < 300) return 4.0 + (adjustedTrimp - 180) / 120 * 0.8;
    return 5.0;
  }
}
