// ── Overview response ─────────────────────────────────────────────────────────

class VolumeHistoryPoint {
  final DateTime date;
  final double volume;

  const VolumeHistoryPoint({required this.date, required this.volume});

  factory VolumeHistoryPoint.fromJson(Map<String, dynamic> json) {
    return VolumeHistoryPoint(
      date: DateTime.parse(json['date'] as String),
      volume: (json['volume'] as num).toDouble(),
    );
  }
}

class AnalyticsOverview {
  final double totalVolume;
  final int totalWorkouts;
  final int totalDurationMinutes;
  final String unit;
  final Map<String, int> muscleDistribution;
  final List<VolumeHistoryPoint> volumeHistory;

  const AnalyticsOverview({
    required this.totalVolume,
    required this.totalWorkouts,
    required this.totalDurationMinutes,
    required this.unit,
    required this.muscleDistribution,
    required this.volumeHistory,
  });

  factory AnalyticsOverview.fromJson(Map<String, dynamic> json) {
    final rawDist = json['muscle_distribution'] as Map<String, dynamic>? ?? {};
    final muscleDistribution = rawDist.map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    );

    final rawHistory = json['volume_history'] as List<dynamic>? ?? [];
    final volumeHistory = rawHistory
        .map((e) => VolumeHistoryPoint.fromJson(e as Map<String, dynamic>))
        .toList();

    return AnalyticsOverview(
      totalVolume: (json['total_volume'] as num).toDouble(),
      totalWorkouts: (json['total_workouts'] as num).toInt(),
      totalDurationMinutes: (json['total_duration_minutes'] as num).toInt(),
      unit: json['unit'] as String? ?? 'kg',
      muscleDistribution: muscleDistribution,
      volumeHistory: volumeHistory,
    );
  }
}

// ── Exercise progression response ─────────────────────────────────────────────

class ExerciseProgressionPoint {
  final DateTime date;
  final double maxWeight;
  final double estimated1rm;

  const ExerciseProgressionPoint({
    required this.date,
    required this.maxWeight,
    required this.estimated1rm,
  });

  factory ExerciseProgressionPoint.fromJson(Map<String, dynamic> json) {
    return ExerciseProgressionPoint(
      date: DateTime.parse(json['date'] as String),
      maxWeight: (json['max_weight'] as num).toDouble(),
      estimated1rm: (json['estimated_1rm'] as num).toDouble(),
    );
  }
}

class ExerciseProgression {
  final String exerciseId;
  final String exerciseName;
  final double maxWeight;
  final double maxEstimated1rm;
  final String unit;
  final List<ExerciseProgressionPoint> history;

  const ExerciseProgression({
    required this.exerciseId,
    required this.exerciseName,
    required this.maxWeight,
    required this.maxEstimated1rm,
    required this.unit,
    required this.history,
  });

  factory ExerciseProgression.fromJson(Map<String, dynamic> json) {
    final rawHistory = json['history'] as List<dynamic>? ?? [];
    return ExerciseProgression(
      exerciseId: json['exercise_id'] as String,
      exerciseName: json['exercise_name'] as String,
      maxWeight: (json['max_weight'] as num).toDouble(),
      maxEstimated1rm: (json['max_estimated_1rm'] as num).toDouble(),
      unit: json['unit'] as String? ?? 'kg',
      history: rawHistory
          .map((e) => ExerciseProgressionPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
