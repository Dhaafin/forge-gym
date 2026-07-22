class ExerciseHistorySet {
  final String id;
  final int setNumber;
  final double weightKg;
  final int reps;
  final String setType;
  final bool isPr;

  const ExerciseHistorySet({
    required this.id,
    required this.setNumber,
    required this.weightKg,
    required this.reps,
    required this.setType,
    required this.isPr,
  });

  factory ExerciseHistorySet.fromJson(Map<String, dynamic> json) {
    return ExerciseHistorySet(
      id: json['id'] as String,
      setNumber: (json['set_number'] as num).toInt(),
      weightKg: (json['weight_kg'] as num).toDouble(),
      reps: (json['reps'] as num).toInt(),
      setType: json['set_type'] as String? ?? 'normal',
      isPr: json['is_pr'] as bool? ?? false,
    );
  }
}

class ExerciseHistorySession {
  final String sessionId;
  final String sessionTitle;
  final DateTime date;
  final List<ExerciseHistorySet> sets;
  final double sessionVolume;
  final double sessionMaxWeight;
  final double sessionEstimated1rm;

  const ExerciseHistorySession({
    required this.sessionId,
    required this.sessionTitle,
    required this.date,
    required this.sets,
    required this.sessionVolume,
    required this.sessionMaxWeight,
    required this.sessionEstimated1rm,
  });

  factory ExerciseHistorySession.fromJson(Map<String, dynamic> json) {
    final rawSets = json['sets'] as List<dynamic>? ?? [];
    return ExerciseHistorySession(
      sessionId: json['session_id'] as String,
      sessionTitle: json['session_title'] as String,
      date: DateTime.parse(json['date'] as String),
      sets: rawSets
          .map((e) => ExerciseHistorySet.fromJson(e as Map<String, dynamic>))
          .toList(),
      sessionVolume: (json['session_volume'] as num).toDouble(),
      sessionMaxWeight: (json['session_max_weight'] as num).toDouble(),
      sessionEstimated1rm: (json['session_estimated_1rm'] as num).toDouble(),
    );
  }
}

class ExerciseHistory {
  final String exerciseId;
  final String exerciseName;
  final String targetMuscle;
  final double allTimeMaxWeight;
  final double allTimeMaxVolume;
  final double estimated1rm;
  final List<ExerciseHistorySession> history;

  const ExerciseHistory({
    required this.exerciseId,
    required this.exerciseName,
    required this.targetMuscle,
    required this.allTimeMaxWeight,
    required this.allTimeMaxVolume,
    required this.estimated1rm,
    required this.history,
  });

  factory ExerciseHistory.fromJson(Map<String, dynamic> json) {
    final rawHistory = json['history'] as List<dynamic>? ?? [];
    return ExerciseHistory(
      exerciseId: json['exercise_id'] as String,
      exerciseName: json['exercise_name'] as String,
      targetMuscle: json['target_muscle'] as String,
      allTimeMaxWeight: (json['all_time_max_weight'] as num).toDouble(),
      allTimeMaxVolume: (json['all_time_max_volume'] as num).toDouble(),
      estimated1rm: (json['estimated_1rm'] as num).toDouble(),
      history: rawHistory
          .map((e) => ExerciseHistorySession.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
