import '../models/user_profile.dart';

/// Static mock data used by the prototype/demo flow.
/// All values are realistic but fabricated — no real users, no BLE, no Firestore.
class MockData {
  MockData._();

  static final UserProfile athleteProfile = UserProfile(
    id: 'demo-athlete-1',
    name: 'Jan Minarik',
    age: 26,
    sex: Sex.male,
    weightKg: 78,
    heightCm: 182,
    restingHr: 54,
    fitnessLevel: FitnessLevel.advanced,
    role: UserRole.athlete,
  );

  static final UserProfile trainerProfile = UserProfile(
    id: 'demo-trainer-1',
    name: 'Coach Eva',
    age: 34,
    sex: Sex.female,
    weightKg: 64,
    heightCm: 170,
    restingHr: 52,
    fitnessLevel: FitnessLevel.advanced,
    role: UserRole.trainer,
  );

  static const String studioName = 'Pulse Studio · Mostar';

  static const List<MockWorkout> recentWorkouts = [
    MockWorkout(
      date: 'Today',
      type: 'HIIT',
      durationMin: 42,
      avgBpm: 156,
      maxBpm: 184,
      calories: 487,
      trimp: 92,
      dominantZone: 4,
      zoneDist: [0, 5, 18, 42, 30, 5],
    ),
    MockWorkout(
      date: 'Yesterday',
      type: 'Strength',
      durationMin: 55,
      avgBpm: 132,
      maxBpm: 168,
      calories: 412,
      trimp: 68,
      dominantZone: 3,
      zoneDist: [0, 12, 35, 38, 12, 3],
    ),
    MockWorkout(
      date: 'Mon 19',
      type: 'Endurance',
      durationMin: 72,
      avgBpm: 142,
      maxBpm: 162,
      calories: 612,
      trimp: 110,
      dominantZone: 3,
      zoneDist: [0, 8, 22, 55, 13, 2],
    ),
    MockWorkout(
      date: 'Sat 17',
      type: 'CrossFit',
      durationMin: 38,
      avgBpm: 161,
      maxBpm: 189,
      calories: 522,
      trimp: 98,
      dominantZone: 4,
      zoneDist: [0, 3, 12, 35, 38, 12],
    ),
  ];

  static const List<MockParticipant> liveSession = [
    MockParticipant(id: 'p1', name: 'Marko Š.', bpm: 168, avgBpm: 152, rank: 1),
    MockParticipant(id: 'p2', name: 'Petra L.', bpm: 162, avgBpm: 148, rank: 2),
    MockParticipant(id: 'p3', name: 'Ivan B.',  bpm: 155, avgBpm: 144, rank: 3),
    MockParticipant(id: 'p4', name: 'Ana M.',   bpm: 148, avgBpm: 140, rank: 4),
    MockParticipant(id: 'p5', name: 'Luka K.',  bpm: 142, avgBpm: 135, rank: 5),
    MockParticipant(id: 'p6', name: 'Maja P.',  bpm: 138, avgBpm: 132, rank: 6),
    MockParticipant(id: 'p7', name: 'Tin S.',   bpm: 132, avgBpm: 128, rank: 7),
    MockParticipant(id: 'p8', name: 'Sara V.',  bpm: 128, avgBpm: 122, rank: 8),
    MockParticipant(id: 'p9', name: 'Filip M.', bpm: 124, avgBpm: 118, rank: 9),
    MockParticipant(id: 'p10', name: 'Iva D.',  bpm: 118, avgBpm: 112, rank: 10),
  ];

  static const List<MockMember> studioMembers = [
    MockMember(name: 'Marko Šarić',  email: 'marko@studio.com', sessions: 24, lastSeen: 'Active now'),
    MockMember(name: 'Petra Lešić',  email: 'petra@studio.com', sessions: 18, lastSeen: '2h ago'),
    MockMember(name: 'Ivan Brkić',   email: 'ivan@studio.com',  sessions: 31, lastSeen: 'Yesterday'),
    MockMember(name: 'Ana Marić',    email: 'ana@studio.com',   sessions: 12, lastSeen: 'Yesterday'),
    MockMember(name: 'Luka Kovač',   email: 'luka@studio.com',  sessions: 22, lastSeen: '3 days ago'),
    MockMember(name: 'Maja Perić',   email: 'maja@studio.com',  sessions: 9,  lastSeen: 'Last week'),
  ];
}

class MockWorkout {
  final String date;
  final String type;
  final int durationMin;
  final int avgBpm;
  final int maxBpm;
  final int calories;
  final int trimp;
  final int dominantZone;

  /// Time in zones — index 0 = rest, 1-5 = zones. Percentages, sum ≈ 100.
  final List<int> zoneDist;

  const MockWorkout({
    required this.date,
    required this.type,
    required this.durationMin,
    required this.avgBpm,
    required this.maxBpm,
    required this.calories,
    required this.trimp,
    required this.dominantZone,
    required this.zoneDist,
  });

  String get durationLabel {
    final m = durationMin;
    final h = m ~/ 60;
    final r = m % 60;
    if (h > 0) return '${h}h ${r}m';
    return '${m}m';
  }
}

class MockParticipant {
  final String id;
  final String name;
  final int bpm;
  final int avgBpm;
  final int rank;
  const MockParticipant({
    required this.id,
    required this.name,
    required this.bpm,
    required this.avgBpm,
    required this.rank,
  });
}

class MockMember {
  final String name;
  final String email;
  final int sessions;
  final String lastSeen;
  const MockMember({
    required this.name,
    required this.email,
    required this.sessions,
    required this.lastSeen,
  });
}
