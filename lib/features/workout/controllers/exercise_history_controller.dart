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

final exerciseHistoryControllerProvider = NotifierProviderFamily<
    ExerciseHistoryController, ExerciseHistoryState, String>(
  ExerciseHistoryController.new,
);

class ExerciseHistoryController
    extends FamilyNotifier<ExerciseHistoryState, String> {
  static const int _limit = 15;

  @override
  ExerciseHistoryState build(String arg) {
    Future.microtask(() => fetchFirstPage());
    return ExerciseHistoryState.initial();
  }

  String get _exerciseId => arg;

  Future<void> fetchFirstPage() async {
    state = state.copyWith(
      status: ExerciseHistoryStatus.loading,
      sessions: [],
      offset: 0,
      hasMore: true,
      clearError: true,
    );
    try {
      final service = ref.read(workoutServiceProvider);
      final result = await service.fetchExerciseHistory(
        exerciseId: _exerciseId,
        limit: _limit,
        offset: 0,
      );
      state = state.copyWith(
        data: result,
        sessions: result.history,
        status: ExerciseHistoryStatus.success,
        hasMore: result.history.length >= _limit,
        offset: result.history.length,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExerciseHistoryStatus.error,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> fetchNextPage() async {
    if (state.status == ExerciseHistoryStatus.loadingMore ||
        !state.hasMore ||
        state.status == ExerciseHistoryStatus.loading) return;

    state = state.copyWith(status: ExerciseHistoryStatus.loadingMore);
    try {
      final service = ref.read(workoutServiceProvider);
      final result = await service.fetchExerciseHistory(
        exerciseId: _exerciseId,
        limit: _limit,
        offset: state.offset,
      );
      state = state.copyWith(
        sessions: [...state.sessions, ...result.history],
        status: ExerciseHistoryStatus.success,
        hasMore: result.history.length >= _limit,
        offset: state.offset + result.history.length,
      );
    } catch (e) {
      state = state.copyWith(
        status: ExerciseHistoryStatus.error,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }
}
