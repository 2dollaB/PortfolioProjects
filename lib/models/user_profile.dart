/// User profile model — stores personal data for HR calculations
class UserProfile {
  final String id; // Firebase UID in production; timestamp string in prototype
  final String name;
  final String email;
  final String? studioId; // Set once the user creates/joins a studio
  final int age;
  final Sex sex;
  final double weightKg;
  final double heightCm;
  final int? restingHr;
  final FitnessLevel fitnessLevel;
  final UserRole role;
  final bool banned; // Set by the admin panel; read-only here (never written back)
  final int? manualHrMax; // User override
  int _dynamicHrMax; // Adjusted during workouts

  UserProfile({
    String? id,
    this.name = '',
    this.email = '',
    this.studioId,
    required this.age,
    required this.sex,
    required this.weightKg,
    required this.heightCm,
    this.restingHr,
    this.fitnessLevel = FitnessLevel.casual,
    this.role = UserRole.athlete,
    this.banned = false,
    this.manualHrMax,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       _dynamicHrMax = 0 {
    _dynamicHrMax = calculatedHrMax;
  }

  /// HRmax using the best formula for this user's sex
  /// Tanaka (2001): 208 − 0.7 × age  — general population
  /// Gulati (2010): 206 − 0.88 × age  — women-specific
  int get calculatedHrMax {
    if (manualHrMax != null) return manualHrMax!;
    switch (sex) {
      case Sex.female:
        return (206 - (0.88 * age)).round(); // Gulati
      case Sex.male:
      case Sex.other:
        return (208 - (0.7 * age)).round(); // Tanaka
    }
  }

  /// Dynamic HRmax — starts at calculated, increases if exceeded in workout
  int get hrMax => _dynamicHrMax > calculatedHrMax ? _dynamicHrMax : calculatedHrMax;

  /// Update dynamic HRmax if user exceeds it during workout
  /// Only adjusts upward, by small margin (detected max + 2)
  void updateDynamicHrMax(int observedMax) {
    if (observedMax > _dynamicHrMax) {
      _dynamicHrMax = observedMax + 2; // Small buffer above observed
    }
  }

  /// Reset dynamic HRmax back to calculated
  void resetDynamicHrMax() {
    _dynamicHrMax = calculatedHrMax;
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? studioId,
    int? age,
    Sex? sex,
    double? weightKg,
    double? heightCm,
    int? restingHr,
    FitnessLevel? fitnessLevel,
    UserRole? role,
    bool? banned,
    int? manualHrMax,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      studioId: studioId ?? this.studioId,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      restingHr: restingHr ?? this.restingHr,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      role: role ?? this.role,
      banned: banned ?? this.banned,
      manualHrMax: manualHrMax ?? this.manualHrMax,
    );
  }

  /// Convert to JSON for local storage
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'studioId': studioId,
        'age': age,
        'sex': sex.name,
        'weightKg': weightKg,
        'heightCm': heightCm,
        'restingHr': restingHr,
        'fitnessLevel': fitnessLevel.name,
        'role': role.name,
        'manualHrMax': manualHrMax,
        'dynamicHrMax': _dynamicHrMax,
      };

  /// Create from JSON (local storage)
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final profile = UserProfile(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      studioId: json['studioId'] as String?,
      age: json['age'] as int,
      sex: Sex.values.firstWhere((e) => e.name == json['sex']),
      weightKg: (json['weightKg'] as num).toDouble(),
      heightCm: (json['heightCm'] as num).toDouble(),
      restingHr: json['restingHr'] as int?,
      fitnessLevel: FitnessLevel.values.firstWhere(
        (e) => e.name == json['fitnessLevel'],
        orElse: () => FitnessLevel.casual,
      ),
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.athlete,
      ),
      banned: json['banned'] as bool? ?? false,
      manualHrMax: json['manualHrMax'] as int?,
    );
    profile._dynamicHrMax = json['dynamicHrMax'] as int? ?? profile.calculatedHrMax;
    return profile;
  }
}

enum Sex {
  male,
  female,
  other;

  String get displayName {
    switch (this) {
      case Sex.male:
        return 'Male';
      case Sex.female:
        return 'Female';
      case Sex.other:
        return 'Other';
    }
  }
}

enum FitnessLevel {
  beginner,
  casual,
  advanced;

  String get displayName {
    switch (this) {
      case FitnessLevel.beginner:
        return 'Beginner';
      case FitnessLevel.casual:
        return 'Casual';
      case FitnessLevel.advanced:
        return 'Advanced';
    }
  }

  String get description {
    switch (this) {
      case FitnessLevel.beginner:
        return 'New to regular exercise';
      case FitnessLevel.casual:
        return 'Exercise 2-3 times/week';
      case FitnessLevel.advanced:
        return 'Train 5+ times/week';
    }
  }
}

enum UserRole {
  athlete,
  trainer;

  String get displayName {
    switch (this) {
      case UserRole.athlete:
        return 'Athlete';
      case UserRole.trainer:
        return 'Trainer';
    }
  }

  String get description {
    switch (this) {
      case UserRole.athlete:
        return 'Join group sessions';
      case UserRole.trainer:
        return 'Host & manage group sessions';
    }
  }
}
