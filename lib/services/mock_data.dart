import '../models/user_profile.dart';
import '../models/workout_summary.dart';

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
      daysAgo: 0,
      type: 'Group',
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
      daysAgo: 1,
      type: 'Solo',
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
      daysAgo: 3,
      type: 'Group',
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
      daysAgo: 5,
      type: 'Solo',
      durationMin: 38,
      avgBpm: 161,
      maxBpm: 189,
      calories: 522,
      trimp: 98,
      dominantZone: 4,
      zoneDist: [0, 3, 12, 35, 38, 12],
    ),
  ];

  /// Adapts [recentWorkouts] into the production read model so demo screens
  /// share the WorkoutSummary-based widgets (home, history).
  static List<WorkoutSummary> recentSummaries() {
    final now = DateTime.now();
    return recentWorkouts.map((m) {
      final start = now.subtract(
        Duration(days: m.daysAgo, minutes: m.durationMin),
      );
      return WorkoutSummary(
        id: '${m.date}-${m.type}',
        type: m.type.toLowerCase(),
        startTime: start,
        endTime: start.add(Duration(minutes: m.durationMin)),
        avgHr: m.avgBpm,
        maxHr: m.maxBpm,
        calories: m.calories,
        trimp: m.trimp,
        dominantZone: m.dominantZone,
        zoneDist: m.zoneDist,
      );
    }).toList();
  }

  /// Up to 24 athletes — used by trainer monitor + TV view.
  /// Names sorted alphabetically by first name so the default alphabetical
  /// sort renders in a sensible order.
  static const List<MockParticipant> liveSession = [
    MockParticipant(id: 'p1',  name: 'Ana Marić',     bpm: 148, avgBpm: 140),
    MockParticipant(id: 'p2',  name: 'Bruno Horvat',  bpm: 136, avgBpm: 130),
    MockParticipant(id: 'p3',  name: 'Daria Šuljić',  bpm: 152, avgBpm: 146),
    MockParticipant(id: 'p4',  name: 'Dino Vuković',  bpm: 144, avgBpm: 138),
    MockParticipant(id: 'p5',  name: 'Filip Mihić',   bpm: 124, avgBpm: 118),
    MockParticipant(id: 'p6',  name: 'Goran Tadić',   bpm: 165, avgBpm: 156),
    MockParticipant(id: 'p7',  name: 'Iva Delić',     bpm: 118, avgBpm: 112),
    MockParticipant(id: 'p8',  name: 'Ivan Brkić',    bpm: 155, avgBpm: 144),
    MockParticipant(id: 'p9',  name: 'Jana Lovrić',   bpm: 140, avgBpm: 134),
    MockParticipant(id: 'p10', name: 'Karla Babić',   bpm: 158, avgBpm: 150),
    MockParticipant(id: 'p11', name: 'Lana Petrov',   bpm: 130, avgBpm: 124),
    MockParticipant(id: 'p12', name: 'Luka Kovač',    bpm: 142, avgBpm: 135),
    MockParticipant(id: 'p13', name: 'Maja Perić',    bpm: 138, avgBpm: 132),
    MockParticipant(id: 'p14', name: 'Marko Šarić',   bpm: 168, avgBpm: 152),
    MockParticipant(id: 'p15', name: 'Mia Crnić',     bpm: 122, avgBpm: 116),
    MockParticipant(id: 'p16', name: 'Niko Zorić',    bpm: 146, avgBpm: 139),
    MockParticipant(id: 'p17', name: 'Petra Lešić',   bpm: 162, avgBpm: 148),
    MockParticipant(id: 'p18', name: 'Rea Šimić',     bpm: 134, avgBpm: 128),
    MockParticipant(id: 'p19', name: 'Sara Vujić',    bpm: 128, avgBpm: 122),
    MockParticipant(id: 'p20', name: 'Stipe Galić',   bpm: 172, avgBpm: 158),
    MockParticipant(id: 'p21', name: 'Tin Skoko',     bpm: 132, avgBpm: 128),
    MockParticipant(id: 'p22', name: 'Toni Andrić',   bpm: 154, avgBpm: 145),
    MockParticipant(id: 'p23', name: 'Vera Ćosić',    bpm: 126, avgBpm: 120),
    MockParticipant(id: 'p24', name: 'Zoran Žilić',   bpm: 160, avgBpm: 150),
  ];

  /// Returns the first [count] participants from [liveSession],
  /// clamped to [1, liveSession.length].
  static List<MockParticipant> liveOf(int count) {
    final clamped = count.clamp(1, liveSession.length);
    return liveSession.take(clamped).toList();
  }

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

  /// How far back the workout happened — keeps [MockData.recentSummaries]
  /// honest about real DateTimes without parsing the display [date].
  final int daysAgo;
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
    required this.daysAgo,
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
  const MockParticipant({
    required this.id,
    required this.name,
    required this.bpm,
    required this.avgBpm,
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
