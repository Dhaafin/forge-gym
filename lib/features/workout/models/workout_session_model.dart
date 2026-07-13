class WorkoutSessionModel {
  final String id;
  final String userId;
  final String title;
  final String startTime;
  final String? endTime;
  final int? durationMinutes;
  final List<dynamic> sets;

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
    return WorkoutSessionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String?,
      durationMinutes: json['duration_minutes'] as int?,
      sets: json['sets'] as List<dynamic>? ?? [],
    );
  }

  DateTime get startDateTime => DateTime.tryParse(startTime) ?? DateTime.now();
}
