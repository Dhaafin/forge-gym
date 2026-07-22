import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/exercise_history_model.dart';
import '../services/workout_service.dart';

enum ExerciseHistoryStatus { initial, loading, loadingMore, success, error }

class ExerciseHistoryState {
  final ExerciseHistory? data;
  final List<ExerciseHistorySession> sessions;
  final ExerciseHistoryStatus status;
  final bool hasMore;
  final int offset;
  final String? error;

  const ExerciseHistoryState({
    this.data,
    required this.sessions,
    required this.status,
    required this.hasMore,
    required this.offset,
    this.error,
  });

  factory ExerciseHistoryState.initial() => const ExerciseHistoryState(
        sessions: [],
        status: ExerciseHistoryStatus.initial,
        hasMore: true,
        offset: 0,
      );

  ExerciseHistoryState copyWith({
    ExerciseHistory? data,
    List<ExerciseHistorySession>? sessions,
    ExerciseHistoryStatus? status,
    bool? hasMore,
    int? offset,
    String? error,
    bool clearError = false,
  }) {
    return ExerciseHistoryState(
      data: data ?? this.data,
      sessions: sessions ?? this.sessions,
      status: status ?? this.status,
      hasMore: hasMore ?? this.hasMore,
      offset: offset ?? this.offset,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final exerciseHistoryControllerProvider = NotifierProvider<
    ExerciseHistoryController, Map<String, ExerciseHistoryState>>(
  ExerciseHistoryController.new,
);

class ExerciseHistoryController
    extends Notifier<Map<String, ExerciseHistoryState>> {
  static const int _limit = 15;

  @override
  Map<String, ExerciseHistoryState> build() {
    return const {};
  }

  Future<void> fetchFirstPage(String exerciseId) async {
    final currentMap = Map<String, ExerciseHistoryState>.from(state);
    final currentState = currentMap[exerciseId] ?? ExerciseHistoryState.initial();

    currentMap[exerciseId] = currentState.copyWith(
      status: ExerciseHistoryStatus.loading,
      sessions: [],
      offset: 0,
      hasMore: true,
      clearError: true,
    );
    state = currentMap;

    try {
      final service = ref.read(workoutServiceProvider);
      final result = await service.fetchExerciseHistory(
        exerciseId: exerciseId,
        limit: _limit,
        offset: 0,
      );

      final updatedMap = Map<String, ExerciseHistoryState>.from(state);
      updatedMap[exerciseId] = ExerciseHistoryState(
        data: result,
        sessions: result.history,
        status: ExerciseHistoryStatus.success,
        hasMore: result.history.length >= _limit,
        offset: result.history.length,
      );
      state = updatedMap;
    } catch (e) {
      final updatedMap = Map<String, ExerciseHistoryState>.from(state);
      updatedMap[exerciseId] = (updatedMap[exerciseId] ?? ExerciseHistoryState.initial()).copyWith(
        status: ExerciseHistoryStatus.error,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      state = updatedMap;
    }
  }

  Future<void> fetchNextPage(String exerciseId) async {
    final currentMap = Map<String, ExerciseHistoryState>.from(state);
    final currentState = currentMap[exerciseId] ?? ExerciseHistoryState.initial();

    if (currentState.status == ExerciseHistoryStatus.loadingMore ||
        !currentState.hasMore ||
        currentState.status == ExerciseHistoryStatus.loading) return;

    currentMap[exerciseId] = currentState.copyWith(status: ExerciseHistoryStatus.loadingMore);
    state = currentMap;

    try {
      final service = ref.read(workoutServiceProvider);
      final result = await service.fetchExerciseHistory(
        exerciseId: exerciseId,
        limit: _limit,
        offset: currentState.offset,
      );

      final updatedMap = Map<String, ExerciseHistoryState>.from(state);
      updatedMap[exerciseId] = currentState.copyWith(
        sessions: [...currentState.sessions, ...result.history],
        status: ExerciseHistoryStatus.success,
        hasMore: result.history.length >= _limit,
        offset: currentState.offset + result.history.length,
      );
      state = updatedMap;
    } catch (e) {
      final updatedMap = Map<String, ExerciseHistoryState>.from(state);
      updatedMap[exerciseId] = (updatedMap[exerciseId] ?? ExerciseHistoryState.initial()).copyWith(
        status: ExerciseHistoryStatus.error,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      state = updatedMap;
    }
  }
}
