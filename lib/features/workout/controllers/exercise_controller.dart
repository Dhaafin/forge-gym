import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/exercise_model.dart';
import '../services/workout_service.dart';

class ExerciseState {
  final List<ExerciseModel> exercises;
  final bool isLoadingFirst;
  final bool isLoadingMore;
  final String searchQuery;
  final String selectedMuscle; // 'All', 'Chest', 'Back', etc.
  final bool hasReachedMax;
  final int offset;
  final String? errorMessage;

  ExerciseState({
    required this.exercises,
    required this.isLoadingFirst,
    required this.isLoadingMore,
    required this.searchQuery,
    required this.selectedMuscle,
    required this.hasReachedMax,
    required this.offset,
    this.errorMessage,
  });

  factory ExerciseState.initial() {
    return ExerciseState(
      exercises: const [],
      isLoadingFirst: false,
      isLoadingMore: false,
      searchQuery: '',
      selectedMuscle: 'All',
      hasReachedMax: false,
      offset: 0,
    );
  }

  ExerciseState copyWith({
    List<ExerciseModel>? exercises,
    bool? isLoadingFirst,
    bool? isLoadingMore,
    String? searchQuery,
    String? selectedMuscle,
    bool? hasReachedMax,
    int? offset,
    String? errorMessage,
  }) {
    return ExerciseState(
      exercises: exercises ?? this.exercises,
      isLoadingFirst: isLoadingFirst ?? this.isLoadingFirst,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedMuscle: selectedMuscle ?? this.selectedMuscle,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      offset: offset ?? this.offset,
      errorMessage: errorMessage,
    );
  }
}

final exerciseControllerProvider = NotifierProvider<ExerciseController, ExerciseState>(ExerciseController.new);

class ExerciseController extends Notifier<ExerciseState> {
  static const int _limit = 20;

  @override
  ExerciseState build() {
    // Initial fetch
    Future.microtask(() => fetchFirstPage());
    return ExerciseState.initial();
  }

  Future<void> fetchFirstPage() async {
    state = state.copyWith(isLoadingFirst: true, errorMessage: null, offset: 0, hasReachedMax: false);
    try {
      final workoutService = ref.read(workoutServiceProvider);

      // If filtering by muscle group (and it's not 'All'), we can pass the muscle name
      // as part of the search query if the backend doesn't have a distinct muscle filter query param,
      // OR we can pass it to search if search works on muscle names.
      // Based on API: "Search by exercise name or target muscle".
      // So search parameter works for both name and muscle!
      String query = state.searchQuery;
      if (state.selectedMuscle != 'All') {
        query = state.selectedMuscle;
      }

      final results = await workoutService.fetchExercises(
        search: query,
        limit: _limit,
        offset: 0,
      );

      state = state.copyWith(
        exercises: results,
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
      final workoutService = ref.read(workoutServiceProvider);

      String query = state.searchQuery;
      if (state.selectedMuscle != 'All') {
        query = state.selectedMuscle;
      }

      final results = await workoutService.fetchExercises(
        search: query,
        limit: _limit,
        offset: state.offset,
      );

      state = state.copyWith(
        exercises: [...state.exercises, ...results],
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
    state = state.copyWith(searchQuery: query, selectedMuscle: 'All'); // reset muscle pill if searching text
    fetchFirstPage();
  }

  void setMuscleGroup(String muscle) {
    if (state.selectedMuscle == muscle) return;
    state = state.copyWith(selectedMuscle: muscle, searchQuery: ''); // reset search text if selecting muscle
    fetchFirstPage();
  }

  Future<void> createExercise(String name, String targetMuscle) async {
    try {
      final workoutService = ref.read(workoutServiceProvider);
      final newExercise = await workoutService.createExercise(
        name: name,
        targetMuscle: targetMuscle,
      );
      state = state.copyWith(
        exercises: [newExercise, ...state.exercises],
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  Future<void> updateExercise(String id, String name, String targetMuscle) async {
    try {
      final workoutService = ref.read(workoutServiceProvider);
      final updated = await workoutService.updateExercise(
        exerciseId: id,
        name: name,
        targetMuscle: targetMuscle,
      );
      final updatedList = state.exercises.map((e) => e.id == id ? updated : e).toList();
      state = state.copyWith(exercises: updatedList);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }

  Future<void> deleteExercise(String id) async {
    try {
      final workoutService = ref.read(workoutServiceProvider);
      await workoutService.deleteExercise(exerciseId: id);
      final updatedList = state.exercises.where((e) => e.id != id).toList();
      state = state.copyWith(exercises: updatedList);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      rethrow;
    }
  }
}
