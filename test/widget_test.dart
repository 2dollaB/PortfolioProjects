import 'package:flutter_test/flutter_test.dart';
import 'package:beatsync/models/workout.dart';
import 'package:beatsync/models/workout_type.dart';
import 'package:beatsync/services/training_load_service.dart';

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
        calories: 350, trimp: 65, trainingEffect: 3.2, hrRecovery: 25,
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

  // ── TrainingLoadService ──
  group('TrainingLoadService', () {
    List<Workout> makeWorkouts(int count) {
      return List.generate(count, (i) {
        final start = DateTime.now().subtract(Duration(days: i));
        final end = start.add(const Duration(minutes: 30));
        final points = List.generate(60, (j) => HrDataPoint(
          bpm: 155, zone: 4,
          timestamp: start.add(Duration(seconds: j * 30)),
        ));
        return Workout(
          id: 'w-$i', startTime: start, endTime: end,
          dataPoints: points,
          analytics: WorkoutAnalytics(
            avgHr: 155, maxHr: 180, minHr: 100,
            calories: 400, trimp: 75, trainingEffect: 3.5, hrRecovery: 20,
            timeInZone: {1: const Duration(minutes: 2), 2: const Duration(minutes: 5),
              3: const Duration(minutes: 8), 4: const Duration(minutes: 10), 5: const Duration(minutes: 5)},
            hrMax: 190,
          ),
          workoutType: WorkoutType.hiit,
        );
      });
    }

    test('acuteLoad sums 7-day TRIMP', () {
      final workouts = makeWorkouts(3);
      final acute = TrainingLoadService.acuteLoad(workouts);
      expect(acute, greaterThan(0));
    });

    test('chronicLoad averages 28-day TRIMP to weekly', () {
      final workouts = makeWorkouts(10);
      final chronic = TrainingLoadService.chronicLoad(workouts);
      expect(chronic, greaterThan(0));
    });

    test('acwr returns 0 when no data', () {
      final ratio = TrainingLoadService.acwr([]);
      expect(ratio, 0);
    });

    test('acwrStatus returns known zones', () {
      expect(TrainingLoadService.acwrStatus(0).label, 'No Data');
      expect(TrainingLoadService.acwrStatus(0.5).label, 'Undertraining');
      expect(TrainingLoadService.acwrStatus(1.0).label, 'Sweet Spot');
      expect(TrainingLoadService.acwrStatus(1.4).label, 'High Risk');
      expect(TrainingLoadService.acwrStatus(2.0).label, 'Danger Zone');
    });
  });
}
