import 'package:flutter_test/flutter_test.dart';
import 'package:beatsync/config/hr_zones.dart';
import 'package:beatsync/models/user_profile.dart';
import 'package:beatsync/models/workout.dart';
import 'package:beatsync/models/workout_type.dart';

void main() {
  // ── HrDataPoint ──
  group('HrDataPoint', () {
    test('toJson and fromJson roundtrip', () {
      final point = HrDataPoint(
        bpm: 145,
        zone: 3,
        timestamp: DateTime(2025, 1, 1, 12, 0),
        rrIntervals: [800, 810, 795],
      );
      final json = point.toJson();
      final restored = HrDataPoint.fromJson(json);
      expect(restored.bpm, 145);
      expect(restored.zone, 3);
      expect(restored.rrIntervals, [800, 810, 795]);
    });

    test('fromJson handles missing rrIntervals', () {
      final json = {
        'bpm': 120,
        'zone': 2,
        'timestamp': '2025-01-01T12:00:00.000',
      };
      final point = HrDataPoint.fromJson(json);
      expect(point.rrIntervals, isEmpty);
    });
  });

  // ── WorkoutType ──
  group('WorkoutType', () {
    test('displayName returns correct strings', () {
      expect(WorkoutType.hiit.displayName, 'HIIT');
      expect(WorkoutType.cardio.displayName, 'Cardio');
    });

    test('hasIntervals true only for HIIT', () {
      expect(WorkoutType.hiit.hasIntervals, true);
      expect(WorkoutType.cardio.hasIntervals, false);
      expect(WorkoutType.strength.hasIntervals, false);
    });
  });

  // ── Workout ──
  group('Workout', () {
    WorkoutAnalytics makeAnalytics({int avgHr = 140, int maxHr = 180}) {
      return WorkoutAnalytics(
        avgHr: avgHr, maxHr: maxHr, minHr: 80,
        calories: 350, beatPoints: 120, hrRecovery: 25,
        timeInZone: {1: const Duration(minutes: 5), 2: const Duration(minutes: 10),
          3: const Duration(minutes: 8), 4: const Duration(minutes: 5), 5: const Duration(minutes: 2)},
        hrMax: 190,
      );
    }

    Workout makeWorkout({int avgBpm = 140}) {
      final start = DateTime(2025, 1, 1, 10, 0);
      final end = start.add(const Duration(minutes: 30));
      final points = List.generate(60, (i) => HrDataPoint(
        bpm: avgBpm, zone: 3,
        timestamp: start.add(Duration(seconds: i * 30)),
      ));
      return Workout(
        id: 'test-1', startTime: start, endTime: end,
        dataPoints: points,
        analytics: makeAnalytics(avgHr: avgBpm),
        workoutType: WorkoutType.hiit,
      );
    }

    test('duration calculates correctly', () {
      final w = makeWorkout();
      expect(w.duration.inMinutes, 30);
    });

    test('analytics avgHr is correct', () {
      final w = makeWorkout(avgBpm: 150);
      expect(w.analytics.avgHr, 150);
    });

    test('copyWith updates notes and rpe', () {
      final w = makeWorkout();
      final updated = w.copyWith(notes: 'Great session', rpe: 7, moodEmoji: '😊');
      expect(updated.notes, 'Great session');
      expect(updated.rpe, 7);
      expect(updated.moodEmoji, '😊');
      expect(updated.id, w.id);
    });

    test('toJson and fromJson roundtrip', () {
      final w = makeWorkout();
      final json = w.toJson();
      final restored = Workout.fromJson(json);
      expect(restored.id, w.id);
      expect(restored.workoutType, WorkoutType.hiit);
      expect(restored.dataPoints.length, w.dataPoints.length);
    });
  });

  // ── BeatPoints ──
  group('BeatPoints', () {
    Workout beatWorkout(int bpm, int hrMax, int minutes) {
      final start = DateTime(2025, 1, 1, 10, 0);
      final samples = minutes * 6; // one every 10s
      final points = List.generate(samples, (i) => HrDataPoint(
        bpm: bpm, zone: HrZones.fromBpm(bpm, hrMax),
        timestamp: start.add(Duration(seconds: i * 10)),
      ));
      return Workout(
        id: 't', startTime: start,
        endTime: start.add(Duration(minutes: minutes)),
        dataPoints: points,
        analytics: AnalyticsEngine.calculate(
          dataPoints: points,
          profile: UserProfile(age: 30, sex: Sex.male, weightKg: 80, heightCm: 180, manualHrMax: hrMax),
          totalDuration: Duration(minutes: minutes),
        ),
      );
    }

    test('zone 4 earns ~4 points/min', () {
      // 85% of 190 = ~161 bpm → zone 4 → 4 pts/min over 10 min ≈ 40.
      final w = beatWorkout(161, 190, 10);
      expect(w.analytics.beatPoints, closeTo(40, 4));
    });

    test('below zone 1 earns nothing', () {
      // 40% of 190 = 76 bpm → zone 0 → 0 points.
      final w = beatWorkout(76, 190, 10);
      expect(w.analytics.beatPoints, 0);
    });

    test('zone 5 is capped at zone-4 rate (no redline bonus)', () {
      final z4 = beatWorkout(161, 190, 10).analytics.beatPoints; // ~85%
      final z5 = beatWorkout(180, 190, 10).analytics.beatPoints; // ~95%
      expect(z5, z4);
    });
  });
}
