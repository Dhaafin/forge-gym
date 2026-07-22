import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/analytics_model.dart';
import '../models/exercise_model.dart';
import '../services/analytics_service.dart';
import '../services/workout_service.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum AnalyticsStatus { loading, success, error }
enum AnalyticsRange { d7, d30, d90, y1, all }

extension AnalyticsRangeExt on AnalyticsRange {
  String get apiValue {
    switch (this) {
      case AnalyticsRange.d7:
        return '7d';
      case AnalyticsRange.d30:
        return '30d';
      case AnalyticsRange.d90:
        return '90d';
      case AnalyticsRange.y1:
        return '1y';
      case AnalyticsRange.all:
        return 'all';
    }
  }

  String get label {
    switch (this) {
      case AnalyticsRange.d7:
        return '7D';
      case AnalyticsRange.d30:
        return '30D';
      case AnalyticsRange.d90:
        return '90D';
      case AnalyticsRange.y1:
        return '1Y';
      case AnalyticsRange.all:
        return 'All';
    }
  }
}

// ── Progression chart toggle ──────────────────────────────────────────────────

enum ProgressionMetric { maxWeight, estimated1rm }

// ── State ─────────────────────────────────────────────────────────────────────

class AnalyticsState {
  final AnalyticsStatus overviewStatus;
  final AnalyticsStatus progressionStatus;
  final AnalyticsRange selectedRange;
  final AnalyticsOverview? overview;
  final String? overviewError;

  // Exercise progression
  final List<ExerciseModel> exercises;
  final ExerciseModel? selectedExercise;
  final ExerciseProgression? progression;
  final String? progressionError;
  final ProgressionMetric progressionMetric;

  const AnalyticsState({
    required this.overviewStatus,
    required this.progressionStatus,
    required this.selectedRange,
    this.overview,
    this.overviewError,
    required this.exercises,
    this.selectedExercise,
    this.progression,
    this.progressionError,
    required this.progressionMetric,
  });

  factory AnalyticsState.initial() {
    return const AnalyticsState(
      overviewStatus: AnalyticsStatus.loading,
      progressionStatus: AnalyticsStatus.loading,
      selectedRange: AnalyticsRange.d30,
      exercises: [],
      progressionMetric: ProgressionMetric.maxWeight,
    );
  }

  AnalyticsState copyWith({
    AnalyticsStatus? overviewStatus,
    AnalyticsStatus? progressionStatus,
    AnalyticsRange? selectedRange,
    AnalyticsOverview? overview,
    String? overviewError,
    bool clearOverviewError = false,
    List<ExerciseModel>? exercises,
    ExerciseModel? selectedExercise,
    bool clearSelectedExercise = false,
    ExerciseProgression? progression,
    bool clearProgression = false,
    String? progressionError,
    bool clearProgressionError = false,
    ProgressionMetric? progressionMetric,
  }) {
    return AnalyticsState(
      overviewStatus: overviewStatus ?? this.overviewStatus,
      progressionStatus: progressionStatus ?? this.progressionStatus,
      selectedRange: selectedRange ?? this.selectedRange,
      overview: overview ?? this.overview,
      overviewError: clearOverviewError ? null : (overviewError ?? this.overviewError),
      exercises: exercises ?? this.exercises,
      selectedExercise: clearSelectedExercise
          ? null
          : (selectedExercise ?? this.selectedExercise),
      progression: clearProgression ? null : (progression ?? this.progression),
      progressionError: clearProgressionError
          ? null
          : (progressionError ?? this.progressionError),
      progressionMetric: progressionMetric ?? this.progressionMetric,
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final analyticsControllerProvider =
    NotifierProvider<AnalyticsController, AnalyticsState>(
  AnalyticsController.new,
);

// ── Controller ────────────────────────────────────────────────────────────────

class AnalyticsController extends Notifier<AnalyticsState> {
  @override
  AnalyticsState build() {
    Future.microtask(() => loadAnalyticsData());
    return AnalyticsState.initial();
  }

  Future<void> loadAnalyticsData() async {
    state = state.copyWith(
      overviewStatus: AnalyticsStatus.loading,
      clearOverviewError: true,
    );
    try {
      final analyticsService = ref.read(analyticsServiceProvider);
      final workoutService = ref.read(workoutServiceProvider);

      // Fetch overview and exercises concurrently
      final results = await Future.wait([
        analyticsService.fetchOverview(range: state.selectedRange.apiValue),
        _fetchAllExercises(workoutService),
      ]);

      final overview = results[0] as AnalyticsOverview;
      final exercises = results[1] as List<ExerciseModel>;

      state = state.copyWith(
        overviewStatus: AnalyticsStatus.success,
        overview: overview,
        exercises: exercises,
      );

      // Fetch progression for selected exercise if there is one
      if (state.selectedExercise != null) {
        _fetchProgression(state.selectedExercise!.id);
      } else {
        state = state.copyWith(
          progressionStatus: AnalyticsStatus.success,
          clearProgression: true,
        );
      }
    } catch (e) {
      state = state.copyWith(
        overviewStatus: AnalyticsStatus.error,
        overviewError: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void clearSelection() {
    state = state.copyWith(
      clearSelectedExercise: true,
      clearProgression: true,
      progressionStatus: AnalyticsStatus.success,
    );
  }

  Future<void> setRange(AnalyticsRange range) async {
    if (state.selectedRange == range) return;
    state = state.copyWith(selectedRange: range);
    await _fetchOverview();
  }

  Future<void> selectExercise(ExerciseModel exercise) async {
    if (state.selectedExercise?.id == exercise.id) return;
    state = state.copyWith(
      selectedExercise: exercise,
      clearProgression: true,
      progressionStatus: AnalyticsStatus.loading,
    );
    await _fetchProgression(exercise.id);
  }

  void setProgressionMetric(ProgressionMetric metric) {
    if (state.progressionMetric == metric) return;
    state = state.copyWith(progressionMetric: metric);
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  Future<void> _fetchOverview() async {
    state = state.copyWith(
      overviewStatus: AnalyticsStatus.loading,
      clearOverviewError: true,
    );
    try {
      final service = ref.read(analyticsServiceProvider);
      final overview = await service.fetchOverview(range: state.selectedRange.apiValue);
      state = state.copyWith(
        overviewStatus: AnalyticsStatus.success,
        overview: overview,
      );
    } catch (e) {
      state = state.copyWith(
        overviewStatus: AnalyticsStatus.error,
        overviewError: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<void> _fetchProgression(String exerciseId) async {
    state = state.copyWith(
      progressionStatus: AnalyticsStatus.loading,
      clearProgressionError: true,
    );
    try {
      final service = ref.read(analyticsServiceProvider);
      final progression = await service.fetchExerciseProgression(exerciseId: exerciseId);
      state = state.copyWith(
        progressionStatus: AnalyticsStatus.success,
        progression: progression,
      );
    } catch (e) {
      state = state.copyWith(
        progressionStatus: AnalyticsStatus.error,
        progressionError: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<List<ExerciseModel>> _fetchAllExercises(WorkoutService service) async {
    final List<ExerciseModel> all = [];
    int offset = 0;
    const limit = 50;
    bool hasMore = true;
    while (hasMore) {
      final chunk = await service.fetchExercises(limit: limit, offset: offset);
      all.addAll(chunk);
      if (chunk.length < limit) {
        hasMore = false;
      } else {
        offset += limit;
      }
    }
    return all;
  }
}
