class WorkoutSetModel {
  final String id;
  final String sessionId;
  final String exerciseId;
  final String exerciseName;
  final int setNumber;
  final double weightKg;
  final int reps;
  final String setType; // e.g. normal, warmup, dropset
  final bool isPr;

  WorkoutSetModel({
    required this.id,
    required this.sessionId,
    required this.exerciseId,
    required this.exerciseName,
    required this.setNumber,
    required this.weightKg,
    required this.reps,
    required this.setType,
    required this.isPr,
  });

  factory WorkoutSetModel.fromJson(Map<String, dynamic> json) {
    return WorkoutSetModel(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      exerciseId: json['exercise_id'] as String,
      exerciseName: json['exercise_name'] as String? ?? '',
      setNumber: json['set_number'] as int? ?? 1,
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0.0,
      reps: json['reps'] as int? ?? 0,
      setType: json['set_type'] as String? ?? 'normal',
      isPr: json['is_pr'] as bool? ?? false,
    );
  }

  WorkoutSetModel copyWith({
    String? id,
    String? sessionId,
    String? exerciseId,
    String? exerciseName,
    int? setNumber,
    double? weightKg,
    int? reps,
    String? setType,
    bool? isPr,
  }) {
    return WorkoutSetModel(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      setNumber: setNumber ?? this.setNumber,
      weightKg: weightKg ?? this.weightKg,
      reps: reps ?? this.reps,
      setType: setType ?? this.setType,
      isPr: isPr ?? this.isPr,
    );
  }
}

class WorkoutSessionModel {
  final String id;
  final String userId;
  final String title;
  final String startTime;
  final String? endTime;
  final int? durationMinutes;
  final List<WorkoutSetModel> sets;

  WorkoutSessionModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.startTime,
    this.endTime,
    this.durationMinutes,
    required this.sets,
  });

  factory WorkoutSessionModel.fromJson(Map<String, dynamic> json) {
    final rawSets = json['sets'] as List<dynamic>? ?? [];
    final typedSets = rawSets.map((s) => WorkoutSetModel.fromJson(s as Map<String, dynamic>)).toList();
    return WorkoutSessionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String?,
      durationMinutes: json['duration_minutes'] as int?,
      sets: typedSets,
    );
  }

  DateTime get startDateTime => DateTime.tryParse(startTime) ?? DateTime.now();

  WorkoutSessionModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? startTime,
    String? endTime,
    int? durationMinutes,
    List<WorkoutSetModel>? sets,
  }) {
    return WorkoutSessionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      sets: sets ?? this.sets,
    );
  }
}
