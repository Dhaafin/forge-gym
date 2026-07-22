class UserProfileModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final bool isActive;
  final DateTime createdAt;
  final String preferredUnit;
  final double? weightKg;
  final double? heightCm;
  final String? fitnessGoal;
  final String? experienceLevel;
  final String? injuriesOrLimitations;

  const UserProfileModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    required this.createdAt,
    required this.preferredUnit,
    this.weightKg,
    this.heightCm,
    this.fitnessGoal,
    this.experienceLevel,
    this.injuriesOrLimitations,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      preferredUnit: json['preferred_unit'] as String? ?? 'metric',
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      fitnessGoal: json['fitness_goal'] as String?,
      experienceLevel: json['experience_level'] as String?,
      injuriesOrLimitations: json['injuries_or_limitations'] as String?,
    );
  }

  UserProfileModel copyWith({
    String? name,
    String? preferredUnit,
    double? weightKg,
    double? heightCm,
    String? fitnessGoal,
    String? experienceLevel,
    String? injuriesOrLimitations,
    bool clearInjuries = false,
  }) {
    return UserProfileModel(
      id: id,
      name: name ?? this.name,
      email: email,
      role: role,
      isActive: isActive,
      createdAt: createdAt,
      preferredUnit: preferredUnit ?? this.preferredUnit,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      injuriesOrLimitations:
          clearInjuries ? null : (injuriesOrLimitations ?? this.injuriesOrLimitations),
    );
  }
}

// ── Enum helpers for display labels ──────────────────────────────────────────

const fitnessGoalOptions = <String, String>{
  'build_muscle': 'Build Muscle',
  'lose_fat': 'Lose Fat',
  'increase_strength': 'Increase Strength',
  'endurance': 'Endurance',
  'general_health': 'General Health',
};

const experienceLevelOptions = <String, String>{
  'beginner': 'Beginner',
  'intermediate': 'Intermediate',
  'advanced': 'Advanced',
};

String fitnessGoalLabel(String? value) =>
    fitnessGoalOptions[value] ?? 'Not set';

String experienceLevelLabel(String? value) =>
    experienceLevelOptions[value] ?? 'Not set';
