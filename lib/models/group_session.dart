/// Represents a completed group training session (5.4)
class GroupSession {
  final String id;
  final String sessionName;
  final DateTime startTime;
  final Duration duration;
  final List<GroupParticipant> participants;

  GroupSession({
    required this.id,
    required this.sessionName,
    required this.startTime,
    required this.duration,
    required this.participants,
  });

  // Aggregate stats
  int get participantCount => participants.length;
  double get avgGroupHr {
    if (participants.isEmpty) return 0;
    return participants.fold(0.0, (s, p) => s + p.avgBpm) / participants.length;
  }
  int get maxBpmRecorded => participants.isEmpty
      ? 0
      : participants.map((p) => p.maxBpm).reduce((a, b) => a > b ? a : b);

  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionName': sessionName,
    'startTime': startTime.toIso8601String(),
    'durationSeconds': duration.inSeconds,
    'participants': participants.map((p) => p.toJson()).toList(),
  };

  factory GroupSession.fromJson(Map<String, dynamic> j) => GroupSession(
    id: j['id'] as String,
    sessionName: j['sessionName'] as String? ?? 'Session',
    startTime: DateTime.parse(j['startTime'] as String),
    duration: Duration(seconds: j['durationSeconds'] as int? ?? 0),
    participants: ((j['participants'] as List?) ?? [])
        .map((p) => GroupParticipant.fromJson(p as Map<String, dynamic>))
        .toList(),
  );
}

/// A single athlete's contribution to a group session
class GroupParticipant {
  final String userId;
  final String name;
  final int avgBpm;
  final int maxBpm;
  final int hrMax;
  /// Seconds spent in each zone {1: 120, 2: 300, ...}
  final Map<int, int> timeInZoneSeconds;

  GroupParticipant({
    required this.userId,
    required this.name,
    required this.avgBpm,
    required this.maxBpm,
    required this.hrMax,
    required this.timeInZoneSeconds,
  });

  int get dominantZone {
    if (timeInZoneSeconds.isEmpty) return 0;
    return timeInZoneSeconds.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  double get avgHrPct => hrMax > 0 ? avgBpm / hrMax * 100 : 0;

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'name': name,
    'avgBpm': avgBpm,
    'maxBpm': maxBpm,
    'hrMax': hrMax,
    'timeInZoneSeconds': timeInZoneSeconds.map((k, v) => MapEntry('$k', v)),
  };

  factory GroupParticipant.fromJson(Map<String, dynamic> j) => GroupParticipant(
    userId: j['userId'] as String,
    name: j['name'] as String? ?? 'Athlete',
    avgBpm: j['avgBpm'] as int? ?? 0,
    maxBpm: j['maxBpm'] as int? ?? 0,
    hrMax: j['hrMax'] as int? ?? 180,
    timeInZoneSeconds: ((j['timeInZoneSeconds'] as Map?) ?? {})
        .map((k, v) => MapEntry(int.parse(k as String), v as int)),
  );
}
