import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/strings.dart';

/// Read-side view of a `workouts/{id}` doc — the summary fields the history
/// and home cards render. (The write side lives in WorkoutRepository.save.)
class WorkoutSummary {
  final String id;

  /// Owner uid — only populated by cross-athlete reads (session detail),
  /// where attribution matters; per-user queries leave it null.
  final String? userId;
  final String type; // 'group' | 'solo'
  final DateTime startTime;
  final DateTime endTime;
  final int avgHr;
  final int maxHr;
  final int calories;
  final int trimp;
  final int dominantZone;
  final List<int> zoneDist; // 6 entries (zone 0-5), percentages

  const WorkoutSummary({
    required this.id,
    this.userId,
    required this.type,
    required this.startTime,
    required this.endTime,
    required this.avgHr,
    required this.maxHr,
    required this.calories,
    required this.trimp,
    required this.dominantZone,
    required this.zoneDist,
  });

  Duration get duration => endTime.difference(startTime);
  int get durationMin => duration.inMinutes;

  String get durationLabel {
    final m = durationMin;
    final h = m ~/ 60;
    final r = m % 60;
    return h > 0 ? '${h}h ${r}m' : '${m}m';
  }

  String get typeLabel {
    if (type.isEmpty) return 'Workout';
    return type[0].toUpperCase() + type.substring(1);
  }

  String get dateLabel {
    final now = DateTime.now();
    final d = DateTime(startTime.year, startTime.month, startTime.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return Strings.today;
    if (diff == 1) return Strings.yesterday;
    if (diff < 7) return Strings.daysAgo(diff);
    return '${startTime.day}/${startTime.month}';
  }

  factory WorkoutSummary.fromDoc(String id, Map<String, dynamic> d) {
    DateTime ts(dynamic v) => v is Timestamp
        ? v.toDate()
        : DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    return WorkoutSummary(
      id: id,
      userId: d['userId'] as String?,
      type: d['type'] as String? ?? 'solo',
      startTime: ts(d['startTime']),
      endTime: ts(d['endTime']),
      avgHr: (d['avgHr'] as num?)?.toInt() ?? 0,
      maxHr: (d['maxHr'] as num?)?.toInt() ?? 0,
      calories: (d['calories'] as num?)?.toInt() ?? 0,
      trimp: (d['trimp'] as num?)?.toInt() ?? 0,
      dominantZone: (d['dominantZone'] as num?)?.toInt() ?? 1,
      zoneDist:
          (d['zoneDist'] as List?)?.map((e) => (e as num).toInt()).toList() ??
          const [0, 0, 0, 0, 0, 0],
    );
  }
}
