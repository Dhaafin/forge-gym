import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/controllers/auth_controller.dart';
import '../models/workout_session_model.dart';
import '../services/workout_service.dart';
import 'exercise_controller.dart';

class WorkoutHistoryState {
  final List<WorkoutSessionModel> sessions;
  final bool isLoadingFirst;
  final bool isLoadingMore;
  final String searchQuery;
  final bool hasReachedMax;
  final int offset;
  final String? errorMessage;

  WorkoutHistoryState({
    required this.sessions,
    required this.isLoadingFirst,
    required this.isLoadingMore,
    required this.searchQuery,
    required this.hasReachedMax,
    required this.offset,
    this.errorMessage,
  });

  factory WorkoutHistoryState.initial() {
    return WorkoutHistoryState(
      sessions: const [],
      isLoadingFirst: false,
      isLoadingMore: false,
      searchQuery: '',
      hasReachedMax: false,
      offset: 0,
    );
  }

  WorkoutHistoryState copyWith({
    List<WorkoutSessionModel>? sessions,
    bool? isLoadingFirst,
    bool? isLoadingMore,
    String? searchQuery,
    bool? hasReachedMax,
    int? offset,
    String? errorMessage,
  }) {
    return WorkoutHistoryState(
      sessions: sessions ?? this.sessions,
      isLoadingFirst: isLoadingFirst ?? this.isLoadingFirst,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      searchQuery: searchQuery ?? this.searchQuery,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      offset: offset ?? this.offset,
      errorMessage: errorMessage,
    );
  }
}

final workoutHistoryControllerProvider =
    NotifierProvider<WorkoutHistoryController, WorkoutHistoryState>(
  WorkoutHistoryController.new,
);

class WorkoutHistoryController extends Notifier<WorkoutHistoryState> {
  static const int _limit = 20;

  @override
  WorkoutHistoryState build() {
    Future.microtask(() => fetchFirstPage());
    return WorkoutHistoryState.initial();
  }

  Future<void> fetchFirstPage() async {
    state = state.copyWith(
      isLoadingFirst: true,
      errorMessage: null,
      offset: 0,
      hasReachedMax: false,
    );
    try {
      final token = ref.read(authControllerProvider).value;
      final service = ref.read(workoutServiceProvider);

      final results = await service.fetchWorkoutHistory(
        search: state.searchQuery.trim().isEmpty ? null : state.searchQuery,
        limit: _limit,
        offset: 0,
        token: token,
      );

      state = state.copyWith(
        sessions: results,
        isLoadingFirst: false,
        hasReachedMax: results.length < _limit,
        offset: results.length,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingFirst: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> fetchNextPage() async {
    if (state.isLoadingMore || state.hasReachedMax || state.isLoadingFirst) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final token = ref.read(authControllerProvider).value;
      final service = ref.read(workoutServiceProvider);

      final results = await service.fetchWorkoutHistory(
        search: state.searchQuery.trim().isEmpty ? null : state.searchQuery,
        limit: _limit,
        offset: state.offset,
        token: token,
      );

      state = state.copyWith(
        sessions: [...state.sessions, ...results],
        isLoadingMore: false,
        hasReachedMax: results.length < _limit,
        offset: state.offset + results.length,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: e.toString(),
      );
    }
  }

  void setSearch(String query) {
    if (state.searchQuery == query) return;
    state = state.copyWith(searchQuery: query);
    fetchFirstPage();
  }

  Future<void> updateSession(String id, String title, int durationMinutes) async {
    try {
      final token = ref.read(authControllerProvider).value;
      final service = ref.read(workoutServiceProvider);
      final updated = await service.updateWorkoutSession(
        sessionId: id,
        title: title,
        durationMinutes: durationMinutes,
        token: token,
      );
      
      final updatedList = state.sessions.map((s) => s.id == id ? updated : s).toList();
      state = state.copyWith(sessions: updatedList);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  Future<void> deleteSession(String id) async {
    try {
      final token = ref.read(authControllerProvider).value;
      final service = ref.read(workoutServiceProvider);
      await service.deleteWorkoutSession(sessionId: id, token: token);
      
      final updatedList = state.sessions.where((s) => s.id != id).toList();
      state = state.copyWith(sessions: updatedList);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  Future<void> updateSet(String sessionId, String setId, double weightKg, int reps, String setType) async {
    try {
      final token = ref.read(authControllerProvider).value;
      final service = ref.read(workoutServiceProvider);
      final updatedSet = await service.updateWorkoutSet(
        setId: setId,
        weightKg: weightKg,
        reps: reps,
        setType: setType,
        token: token,
      );

      final updatedList = state.sessions.map((session) {
        if (session.id == sessionId) {
          final updatedSets = session.sets.map((set) {
            return set.id == setId ? updatedSet : set;
          }).toList();
          return session.copyWith(sets: updatedSets);
        }
        return session;
      }).toList();

      state = state.copyWith(sessions: updatedList);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  Future<void> deleteSet(String sessionId, String setId) async {
    try {
      final token = ref.read(authControllerProvider).value;
      final service = ref.read(workoutServiceProvider);
      await service.deleteWorkoutSet(setId: setId, token: token);

      final updatedList = state.sessions.map((session) {
        if (session.id == sessionId) {
          final updatedSets = session.sets.where((set) => set.id != setId).toList();
          return session.copyWith(sets: updatedSets);
        }
        return session;
      }).toList();

      state = state.copyWith(sessions: updatedList);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }
}
