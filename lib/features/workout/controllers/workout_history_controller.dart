import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workout_session_model.dart';
import '../services/workout_service.dart';

enum WorkoutSortOption {
  newest('Newest', 'start_time', 'desc'),
  oldest('Oldest', 'start_time', 'asc'),
  durationDesc('Longest Duration', 'duration_minutes', 'desc'),
  setsDesc('Most Sets', 'sets_count', 'desc');

  final String label;
  final String sortBy;
  final String order;
  const WorkoutSortOption(this.label, this.sortBy, this.order);
}

class WorkoutHistoryState {
  final List<WorkoutSessionModel> sessions;
  final bool isLoadingFirst;
  final bool isLoadingMore;
  final String searchQuery;
  final String selectedDateFilter; // 'All', 'This Month', 'This Year'
  final WorkoutSortOption selectedSortOption;
  final bool hasReachedMax;
  final int offset;
  final String? errorMessage;

  WorkoutHistoryState({
    required this.sessions,
    required this.isLoadingFirst,
    required this.isLoadingMore,
    required this.searchQuery,
    required this.selectedDateFilter,
    required this.selectedSortOption,
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
      selectedDateFilter: 'All',
      selectedSortOption: WorkoutSortOption.newest,
      hasReachedMax: false,
      offset: 0,
    );
  }

  List<WorkoutSessionModel> get displaySessions {
    final now = DateTime.now();

    // 1. Filter by Date Range
    var list = sessions.where((s) {
      if (selectedDateFilter == 'This Month') {
        return s.startDateTime.year == now.year && s.startDateTime.month == now.month;
      } else if (selectedDateFilter == 'This Year') {
        return s.startDateTime.year == now.year;
      }
      return true; // 'All'
    }).toList();

    // 2. Sort List
    list.sort((a, b) {
      switch (selectedSortOption) {
        case WorkoutSortOption.newest:
          return b.startDateTime.compareTo(a.startDateTime);
        case WorkoutSortOption.oldest:
          return a.startDateTime.compareTo(b.startDateTime);
        case WorkoutSortOption.durationDesc:
          return (b.durationMinutes ?? 0).compareTo(a.durationMinutes ?? 0);
        case WorkoutSortOption.setsDesc:
          return b.sets.length.compareTo(a.sets.length);
      }
    });

    return list;
  }

  WorkoutHistoryState copyWith({
    List<WorkoutSessionModel>? sessions,
    bool? isLoadingFirst,
    bool? isLoadingMore,
    String? searchQuery,
    String? selectedDateFilter,
    WorkoutSortOption? selectedSortOption,
    bool? hasReachedMax,
    int? offset,
    String? errorMessage,
  }) {
    return WorkoutHistoryState(
      sessions: sessions ?? this.sessions,
      isLoadingFirst: isLoadingFirst ?? this.isLoadingFirst,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedDateFilter: selectedDateFilter ?? this.selectedDateFilter,
      selectedSortOption: selectedSortOption ?? this.selectedSortOption,
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
      final service = ref.read(workoutServiceProvider);

      final results = await service.fetchWorkoutHistory(
        search: state.searchQuery.trim().isEmpty ? null : state.searchQuery,
        limit: _limit,
        offset: 0,
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
      final service = ref.read(workoutServiceProvider);

      final results = await service.fetchWorkoutHistory(
        search: state.searchQuery.trim().isEmpty ? null : state.searchQuery,
        limit: _limit,
        offset: state.offset,
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

  void setDateFilter(String filter) {
    if (state.selectedDateFilter == filter) return;
    state = state.copyWith(selectedDateFilter: filter);
  }

  void setSortOption(WorkoutSortOption sort) {
    if (state.selectedSortOption == sort) return;
    state = state.copyWith(selectedSortOption: sort);
  }

  void resetSortToNewest() {
    if (state.selectedSortOption == WorkoutSortOption.newest &&
        state.selectedDateFilter == 'All') return;
    state = state.copyWith(
      selectedSortOption: WorkoutSortOption.newest,
      selectedDateFilter: 'All',
    );
  }

  void addSession(WorkoutSessionModel session) {
    state = state.copyWith(
      sessions: [session, ...state.sessions],
      offset: state.offset + 1,
    );
  }

  void updateSessionInList(WorkoutSessionModel updated) {
    final updatedList = state.sessions.map<WorkoutSessionModel>((s) => s.id == updated.id ? updated : s).toList();
    state = state.copyWith(sessions: updatedList);
  }

  Future<void> deleteSession(String id) async {
    try {
      final service = ref.read(workoutServiceProvider);
      await service.deleteWorkoutSession(sessionId: id);
      
      final updatedList = state.sessions.where((s) => s.id != id).toList();
      state = state.copyWith(sessions: updatedList);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  Future<void> updateSet(String sessionId, String setId, double weightKg, int reps, String setType) async {
    try {
      final service = ref.read(workoutServiceProvider);
      final updatedSet = await service.updateWorkoutSet(
        setId: setId,
        weightKg: weightKg,
        reps: reps,
        setType: setType,
      );

      final updatedList = state.sessions.map<WorkoutSessionModel>((session) {
        if (session.id == sessionId) {
          final updatedSets = session.sets.map<WorkoutSetModel>((set) {
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
      final service = ref.read(workoutServiceProvider);
      await service.deleteWorkoutSet(setId: setId);

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
