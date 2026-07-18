import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/workout_session_model.dart';
import '../models/exercise_model.dart';
import '../services/workout_service.dart';

enum AnalyticsStatus { loading, success, error }
enum AnalyticsPeriod { week, month, year }

class ProgressPoint {
  final String label;
  final double value;
  ProgressPoint(this.label, this.value);
}

class AnalyticsState {
  final AnalyticsStatus status;
  final AnalyticsPeriod period;
  final double totalVolume;
  final int workoutCount;
  final double avgDuration;
  final int prsCount;
  final Map<String, double> muscleGroupShares;
  final List<ProgressPoint> volumePoints;
  final List<ProgressPoint> frequencyPoints;
  final String? errorMessage;

  AnalyticsState({
    required this.status,
    required this.period,
    required this.totalVolume,
    required this.workoutCount,
    required this.avgDuration,
    required this.prsCount,
    required this.muscleGroupShares,
    required this.volumePoints,
    required this.frequencyPoints,
    this.errorMessage,
  });

  factory AnalyticsState.initial() {
    return AnalyticsState(
      status: AnalyticsStatus.loading,
      period: AnalyticsPeriod.week,
      totalVolume: 0.0,
      workoutCount: 0,
      avgDuration: 0.0,
      prsCount: 0,
      muscleGroupShares: const {},
      volumePoints: const [],
      frequencyPoints: const [],
    );
  }

  AnalyticsState copyWith({
    AnalyticsStatus? status,
    AnalyticsPeriod? period,
    double? totalVolume,
    int? workoutCount,
    double? avgDuration,
    int? prsCount,
    Map<String, double>? muscleGroupShares,
    List<ProgressPoint>? volumePoints,
    List<ProgressPoint>? frequencyPoints,
    String? errorMessage,
  }) {
    return AnalyticsState(
      status: status ?? this.status,
      period: period ?? this.period,
      totalVolume: totalVolume ?? this.totalVolume,
      workoutCount: workoutCount ?? this.workoutCount,
      avgDuration: avgDuration ?? this.avgDuration,
      prsCount: prsCount ?? this.prsCount,
      muscleGroupShares: muscleGroupShares ?? this.muscleGroupShares,
      volumePoints: volumePoints ?? this.volumePoints,
      frequencyPoints: frequencyPoints ?? this.frequencyPoints,
      errorMessage: errorMessage,
    );
  }
}

final analyticsControllerProvider = NotifierProvider<AnalyticsController, AnalyticsState>(AnalyticsController.new);

class AnalyticsController extends Notifier<AnalyticsState> {
  List<WorkoutSessionModel> _allSessions = [];
  Map<String, ExerciseModel> _exerciseMap = {};

  @override
  AnalyticsState build() {
    Future.microtask(() => loadAnalyticsData());
    return AnalyticsState.initial();
  }

  Future<void> loadAnalyticsData() async {
    state = state.copyWith(status: AnalyticsStatus.loading, errorMessage: null);
    try {
      final service = ref.read(workoutServiceProvider);
      
      // 1. Fetch exercises to map exerciseId to targetMuscle using pagination loop to bypass backend max limit constraints
      final List<ExerciseModel> exercises = [];
      int offset = 0;
      const int fetchLimit = 50;
      bool hasMore = true;

      while (hasMore) {
        final chunk = await service.fetchExercises(limit: fetchLimit, offset: offset);
        exercises.addAll(chunk);
        if (chunk.length < fetchLimit) {
          hasMore = false;
        } else {
          offset += fetchLimit;
        }
      }

      _exerciseMap = {for (var e in exercises) e.id: e};

      // 2. Fetch workout history with a larger limit to have rich analytics data
      _allSessions = await service.fetchWorkoutHistory(limit: 200);

      _calculateMetrics();
    } catch (e) {
      debugPrint('[AnalyticsController] loadAnalyticsData failed: $e');
      state = state.copyWith(
        status: AnalyticsStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void setPeriod(AnalyticsPeriod period) {
    if (state.period == period) return;
    state = state.copyWith(period: period);
    _calculateMetrics();
  }

  void _calculateMetrics() {
    final now = DateTime.now();
    DateTime thresholdDate;

    // Determine date filter threshold
    switch (state.period) {
      case AnalyticsPeriod.week:
        thresholdDate = now.subtract(const Duration(days: 7));
        break;
      case AnalyticsPeriod.month:
        thresholdDate = now.subtract(const Duration(days: 30));
        break;
      case AnalyticsPeriod.year:
        thresholdDate = now.subtract(const Duration(days: 365));
        break;
    }

    // Filter sessions
    final filteredSessions = _allSessions.where((s) => s.startDateTime.isAfter(thresholdDate)).toList();

    // Summary calculations
    double totalVol = 0.0;
    int totalDuration = 0;
    int totalPrs = 0;
    final Map<String, int> muscleSets = {};
    int totalSetsCount = 0;

    for (final s in filteredSessions) {
      totalDuration += s.durationMinutes ?? 0;
      for (final set in s.sets) {
        // Calculate volume: weight * reps
        totalVol += set.weightKg * set.reps;
        
        // Count PRs
        if (set.isPr) totalPrs++;

        // Count sets per muscle group
        final exercise = _exerciseMap[set.exerciseId];
        final muscle = exercise?.targetMuscle ?? 'Other';
        muscleSets[muscle] = (muscleSets[muscle] ?? 0) + 1;
        totalSetsCount++;
      }
    }

    // Calculate muscle group shares (percentage of total sets)
    final Map<String, double> muscleShares = {};
    if (totalSetsCount > 0) {
      muscleSets.forEach((muscle, count) {
        muscleShares[muscle] = count / totalSetsCount;
      });
    }

    // Sort muscle shares and group small ones into 'Other' if there are too many
    // For simplicity, we just use the shares directly

    // Generate progress points for charts
    final List<ProgressPoint> volumePts = [];
    final List<ProgressPoint> freqPts = [];

    if (state.period == AnalyticsPeriod.week) {
      // Group by last 7 days
      final df = DateFormat('E');
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final label = df.format(date); // e.g. "Mon", "Tue"
        
        final daySessions = filteredSessions.where((s) => 
            s.startDateTime.year == date.year && 
            s.startDateTime.month == date.month && 
            s.startDateTime.day == date.day
        ).toList();

        double vol = 0.0;
        for (final s in daySessions) {
          for (final set in s.sets) {
            vol += set.weightKg * set.reps;
          }
        }

        volumePts.add(ProgressPoint(label, vol));
        freqPts.add(ProgressPoint(label, daySessions.length.toDouble()));
      }
    } else if (state.period == AnalyticsPeriod.month) {
      // Group by 4 weeks of the last 30 days
      for (int i = 3; i >= 0; i--) {
        final label = 'W${4 - i}';
        final start = now.subtract(Duration(days: (i + 1) * 7));
        final end = now.subtract(Duration(days: i * 7));

        final weekSessions = filteredSessions.where((s) => 
            s.startDateTime.isAfter(start) && s.startDateTime.isBefore(end)
        ).toList();

        double vol = 0.0;
        for (final s in weekSessions) {
          for (final set in s.sets) {
            vol += set.weightKg * set.reps;
          }
        }

        volumePts.add(ProgressPoint(label, vol));
        freqPts.add(ProgressPoint(label, weekSessions.length.toDouble()));
      }
    } else {
      // Group by last 12 months
      final df = DateFormat('MMM');
      for (int i = 11; i >= 0; i--) {
        // Simple month subtraction (rough approximation of 30 days per month)
        final date = DateTime(now.year, now.month - i, 1);
        final label = df.format(date);

        final monthSessions = filteredSessions.where((s) => 
            s.startDateTime.year == date.year && s.startDateTime.month == date.month
        ).toList();

        double vol = 0.0;
        for (final s in monthSessions) {
          for (final set in s.sets) {
            vol += set.weightKg * set.reps;
          }
        }

        volumePts.add(ProgressPoint(label, vol));
        freqPts.add(ProgressPoint(label, monthSessions.length.toDouble()));
      }
    }

    state = state.copyWith(
      status: AnalyticsStatus.success,
      totalVolume: totalVol,
      workoutCount: filteredSessions.length,
      avgDuration: filteredSessions.isEmpty ? 0.0 : totalDuration / filteredSessions.length,
      prsCount: totalPrs,
      muscleGroupShares: muscleShares,
      volumePoints: volumePts,
      frequencyPoints: freqPts,
    );
  }
}
