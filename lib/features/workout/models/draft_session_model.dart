import 'package:forge/features/workout/models/workout_session_model.dart';

class DraftSessionModel {
  final String id; // local temp id
  final String title;
  final DateTime startTime;
  final DateTime? endTime; // null for live session until finished
  final int? durationMinutes; // override or calculate
  final List<WorkoutSetModel> sets;
  final bool isLive; // distinguish between live mode and past session logging

  DraftSessionModel({
    required this.id,
    required this.title,
    required this.startTime,
    this.endTime,
    this.durationMinutes,
    this.sets = const [],
    this.isLive = true,
  });

  factory DraftSessionModel.fromJson(Map<String, dynamic> json) {
    final rawSets = json['sets'] as List<dynamic>? ?? [];
    final typedSets = rawSets.map((s) => WorkoutSetModel.fromJson(s as Map<String, dynamic>)).toList();
    
    return DraftSessionModel(
      id: json['id'] as String,
      title: json['title'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time'] as String) : null,
      durationMinutes: json['duration_minutes'] as int?,
      sets: typedSets,
      isLive: json['is_live'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'duration_minutes': durationMinutes,
      'sets': sets.map((s) => s.toJson()).toList(),
      'is_live': isLive,
    };
  }

  DraftSessionModel copyWith({
    String? id,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    int? durationMinutes,
    List<WorkoutSetModel>? sets,
    bool? isLive,
  }) {
    return DraftSessionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      sets: sets ?? this.sets,
      isLive: isLive ?? this.isLive,
    );
  }
}
