import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:forge/core/services/notification_manager.dart';
import '../models/draft_session_model.dart';
import '../models/exercise_model.dart';
import '../models/workout_session_model.dart';
import '../services/draft_session_service.dart';
import '../services/workout_service.dart';
import 'workout_history_controller.dart';

final draftSessionServiceProvider = Provider<DraftSessionService>((ref) {
  return DraftSessionService();
});

class LiveSessionState {
  final DraftSessionModel? draft;
  final bool isLoading;
  final Duration elapsedTime;
  final String? error;

  LiveSessionState({
    this.draft,
    this.isLoading = false,
    this.elapsedTime = Duration.zero,
    this.error,
  });

  LiveSessionState copyWith({
    DraftSessionModel? draft,
    bool? isLoading,
    Duration? elapsedTime,
    String? error,
    bool clearError = false,
    bool clearDraft = false,
  }) {
    return LiveSessionState(
      draft: clearDraft ? null : (draft ?? this.draft),
      isLoading: isLoading ?? this.isLoading,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class LiveSessionController extends Notifier<LiveSessionState> {
  Timer? _timer;
  final _uuid = const Uuid();

  @override
  LiveSessionState build() {
    _loadDraft();
    return LiveSessionState();
  }

  Future<void> _loadDraft() async {
    final service = ref.read(draftSessionServiceProvider);
    final draft = await service.loadDraft();
    if (draft != null) {
      state = state.copyWith(draft: draft);
      if (draft.isLive) {
        final elapsed = DateTime.now().difference(draft.startTime);
        state = state.copyWith(elapsedTime: elapsed);
        _startTimer();
        // Re-show and sync notification on startup
        try {
          await NotificationManager.showWorkoutNotification(
            title: draft.title,
            startTime: draft.startTime,
          );
        } catch (e) {
          debugPrint("NotificationManager sync failed: $e");
        }
      }
    }
  }

  void startLiveSession() {
    final newDraft = DraftSessionModel(
      id: _uuid.v4(),
      title: 'Workout Session',
      startTime: DateTime.now(),
      isLive: true,
      sets: [],
    );
    state = state.copyWith(draft: newDraft, elapsedTime: Duration.zero, clearError: true);
    _startTimer();
    _saveDraftToLocal();
  }

  void startPastSession() {
    final newDraft = DraftSessionModel(
      id: _uuid.v4(),
      title: 'Past Workout Session',
      startTime: DateTime.now().subtract(const Duration(hours: 1)),
      endTime: DateTime.now(),
      durationMinutes: 60,
      isLive: false,
      sets: [],
    );
    state = state.copyWith(draft: newDraft, elapsedTime: Duration.zero, clearError: true);
    _saveDraftToLocal();
  }

  void resumeDraft() {
    if (state.draft?.isLive == true) {
      _startTimer();
    }
  }

  void discardDraft() async {
    _timer?.cancel();
    await ref.read(draftSessionServiceProvider).clearDraft();
    await NotificationManager.cancelWorkoutNotification();
    state = state.copyWith(clearDraft: true, elapsedTime: Duration.zero);
  }

  /// Hard-resets controller to initial state. Call this AFTER the UI
  /// has finished navigating away from LiveSessionPage.
  void resetState() {
    _timer?.cancel();
    state = LiveSessionState();
  }

  void updateTitle(String newTitle) {
    if (state.draft == null) return;
    state = state.copyWith(
      draft: state.draft!.copyWith(title: newTitle),
    );
    _saveDraftToLocal();
  }

  void updatePastSessionTimes({DateTime? startTime, DateTime? endTime, int? durationMinutes}) {
    if (state.draft == null || state.draft!.isLive) return;
    state = state.copyWith(
      draft: state.draft!.copyWith(
        startTime: startTime ?? state.draft!.startTime,
        endTime: endTime ?? state.draft!.endTime,
        durationMinutes: durationMinutes ?? state.draft!.durationMinutes,
      ),
    );
    _saveDraftToLocal();
  }

  void startEditSession(WorkoutSessionModel session) {
    final newDraft = DraftSessionModel(
      id: session.id,
      title: session.title,
      startTime: session.startDateTime,
      endTime: session.endTime != null ? (DateTime.tryParse(session.endTime!)?.toLocal() ?? session.startDateTime.add(const Duration(hours: 1))) : session.startDateTime.add(const Duration(hours: 1)),
      durationMinutes: session.durationMinutes ?? 60,
      isLive: false,
      sets: session.sets,
    );
    state = state.copyWith(draft: newDraft, elapsedTime: Duration.zero, clearError: true);
    _saveDraftToLocal();
  }

  void replaceExercise({required String oldExerciseId, required ExerciseModel newExercise}) {
    if (state.draft == null) return;
    final updatedSets = state.draft!.sets.map((set) {
      if (set.exerciseId == oldExerciseId) {
        return set.copyWith(
          exerciseId: newExercise.id,
          exerciseName: newExercise.name,
        );
      }
      return set;
    }).toList();
    state = state.copyWith(
      draft: state.draft!.copyWith(sets: updatedSets),
    );
    _saveDraftToLocal();
  }

  void deleteExercise(String exerciseId) {
    if (state.draft == null) return;
    final updatedSets = state.draft!.sets.where((set) => set.exerciseId != exerciseId).toList();
    state = state.copyWith(
      draft: state.draft!.copyWith(sets: updatedSets),
    );
    _saveDraftToLocal();
  }

  Future<void> parseAndPopulateNotes(String rawText) async {
    if (state.draft == null) return;

    state = state.copyWith(isLoading: true, clearError: false);
    try {
      final service = ref.read(workoutServiceProvider);
      final result = await service.parseWorkoutNotes(rawText);

      final title = result['title'] as String? ?? 'Past Workout Session';
      final dateStr = result['date'] as String?;
      final parsedDate = dateStr != null ? DateTime.tryParse(dateStr)?.toLocal() : null;
      final startTime = parsedDate ?? DateTime.now().subtract(const Duration(hours: 1));

      final rawExercises = result['exercises'] as List<dynamic>? ?? [];
      final List<WorkoutSetModel> allSets = [];

      for (final rawExercise in rawExercises) {
        final exerciseJson = rawExercise as Map<String, dynamic>;
        final matched = exerciseJson['matched'] as bool? ?? false;

        String exerciseId;
        String exerciseName;

        if (matched) {
          exerciseId = exerciseJson['exercise_id'] as String;
          exerciseName = exerciseJson['exercise_name'] as String;
        } else {
          // Unmatched! Auto-create the exercise on the fly
          final rawName = exerciseJson['raw_name'] as String? ?? 'Unnamed Exercise';
          final targetMuscle = exerciseJson['inferred_target_muscle'] as String? ?? TargetMuscle.fullBody;

          debugPrint('[LiveSession] Auto-creating unmatched exercise: $rawName ($targetMuscle)');
          final newExercise = await service.createExercise(
            name: rawName,
            targetMuscle: targetMuscle,
          );
          exerciseId = newExercise.id;
          exerciseName = newExercise.name;
        }

        final rawSets = exerciseJson['sets'] as List<dynamic>? ?? [];
        for (final rawSet in rawSets) {
          final setJson = rawSet as Map<String, dynamic>;
          allSets.add(WorkoutSetModel(
            id: _uuid.v4(),
            sessionId: state.draft!.id,
            exerciseId: exerciseId,
            exerciseName: exerciseName,
            setNumber: setJson['set_number'] as int? ?? 1,
            weightKg: (setJson['weight_kg'] as num?)?.toDouble() ?? 0.0,
            reps: setJson['reps'] as int? ?? 0,
            setType: setJson['set_type'] as String? ?? 'normal',
            isPr: false,
          ));
        }
      }

      final endTime = startTime.add(const Duration(hours: 1));

      state = state.copyWith(
        isLoading: false,
        draft: state.draft!.copyWith(
          title: title,
          startTime: startTime,
          endTime: endTime,
          durationMinutes: 60,
          sets: allSets,
        ),
      );
      _saveDraftToLocal();
    } catch (e) {
      debugPrint('[LiveSession] parseAndPopulateNotes failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      rethrow;
    }
  }

  void populateFromParsedJson(Map<String, dynamic> result) {
    if (state.draft == null) return;

    final title = result['title'] as String? ?? 'Past Workout Session';
    final dateStr = result['date'] as String?;
    final parsedDate = dateStr != null ? DateTime.tryParse(dateStr)?.toLocal() : null;
    final startTime = parsedDate ?? DateTime.now().subtract(const Duration(hours: 1));

    final rawExercises = result['exercises'] as List<dynamic>? ?? [];
    final List<WorkoutSetModel> allSets = [];

    for (final rawExercise in rawExercises) {
      final exerciseJson = rawExercise as Map<String, dynamic>;
      final exerciseId = exerciseJson['exercise_id'] as String?;
      final exerciseName = exerciseJson['exercise_name'] as String? ?? exerciseJson['raw_name'] as String? ?? 'Unnamed';

      if (exerciseId == null || exerciseId.isEmpty) continue;

      final rawSets = exerciseJson['sets'] as List<dynamic>? ?? [];
      for (final rawSet in rawSets) {
        final setJson = rawSet as Map<String, dynamic>;
        allSets.add(WorkoutSetModel(
          id: _uuid.v4(),
          sessionId: state.draft!.id,
          exerciseId: exerciseId,
          exerciseName: exerciseName,
          setNumber: setJson['set_number'] as int? ?? 1,
          weightKg: (setJson['weight_kg'] as num?)?.toDouble() ?? 0.0,
          reps: setJson['reps'] as int? ?? 0,
          setType: setJson['set_type'] as String? ?? 'normal',
          isPr: false,
        ));
      }
    }

    final endTime = startTime.add(const Duration(hours: 1));

    state = state.copyWith(
      draft: state.draft!.copyWith(
        title: title,
        startTime: startTime,
        endTime: endTime,
        durationMinutes: 60,
        sets: allSets,
      ),
    );
    _saveDraftToLocal();
  }

  void addSet({
    required ExerciseModel exercise,
    required double weightKg,
    required int reps,
    required String setType,
  }) {
    if (state.draft == null) return;

    final currentSets = state.draft!.sets;
    final exerciseSets = currentSets.where((s) => s.exerciseId == exercise.id).toList();
    final nextSetNumber = exerciseSets.length + 1;

    final newSet = WorkoutSetModel(
      id: _uuid.v4(),
      sessionId: state.draft!.id,
      exerciseId: exercise.id,
      exerciseName: exercise.name,
      setNumber: nextSetNumber,
      weightKg: weightKg,
      reps: reps,
      setType: setType,
      isPr: false,
    );

    final updatedSets = List<WorkoutSetModel>.from(currentSets)..add(newSet);
    state = state.copyWith(
      draft: state.draft!.copyWith(sets: updatedSets),
    );
    _saveDraftToLocal();
  }

  void deleteSet(String setId) {
    if (state.draft == null) return;
    final updatedSets = state.draft!.sets.where((s) => s.id != setId).toList();
    state = state.copyWith(
      draft: state.draft!.copyWith(sets: updatedSets),
    );
    _saveDraftToLocal();
  }

  /// Submits the workout session to the API.
  ///
  /// Returns `true` on success. State will have `isLoading: false` and the
  /// draft intact — the **caller** is responsible for navigating away and
  /// then calling [resetState] to clean up.
  ///
  /// Returns the saved [WorkoutSessionModel] on success, or `null` on failure.
  Future<WorkoutSessionModel?> finishWorkout({bool isEditing = false}) async {
    if (state.draft == null) return null;

    _timer?.cancel();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final draft = state.draft!;
      final endTime = draft.isLive ? DateTime.now() : (draft.endTime ?? DateTime.now());
      final durationMinutes = draft.isLive
          ? endTime.difference(draft.startTime).inMinutes
          : (draft.durationMinutes ?? 0);

      final setsJson = draft.sets.map((s) => {
        if (isEditing) 'id': s.id,
        'exercise_id': s.exerciseId,
        'set_number': s.setNumber,
        'weight_kg': s.weightKg,
        'reps': s.reps,
        'set_type': s.setType,
      }).toList();

      debugPrint('[LiveSession] Sending ${setsJson.length} sets. isEditing = $isEditing');

      WorkoutSessionModel newSession;
      if (isEditing) {
        newSession = await ref.read(workoutServiceProvider).updateWorkoutSession(
          sessionId: draft.id,
          title: draft.title,
          startTime: draft.startTime.toUtc().toIso8601String(),
          endTime: endTime.toUtc().toIso8601String(),
          durationMinutes: durationMinutes,
          sets: setsJson,
        );
      } else {
        newSession = await ref.read(workoutServiceProvider).createWorkoutSession(
          title: draft.title,
          startTime: draft.startTime.toUtc().toIso8601String(),
          endTime: endTime.toUtc().toIso8601String(),
          durationMinutes: durationMinutes,
          sets: setsJson,
        );
      }

      // Clear persisted draft and sync locally.
      await ref.read(draftSessionServiceProvider).clearDraft();
      await NotificationManager.cancelWorkoutNotification();
      
      if (isEditing) {
        ref.read(workoutHistoryControllerProvider.notifier).updateSessionInList(newSession);
      } else {
        ref.read(workoutHistoryControllerProvider.notifier).addSession(newSession);
      }

      debugPrint('[LiveSession] Workout saved successfully.');
      state = state.copyWith(isLoading: false);
      return newSession;
    } catch (e) {
      debugPrint('[LiveSession] finishWorkout failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      // Resume timer if this was a live session.
      if (state.draft?.isLive == true) _startTimer();
      return null;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.draft != null) {
        final elapsed = DateTime.now().difference(state.draft!.startTime);
        state = state.copyWith(elapsedTime: elapsed);
        if (timer.tick % 30 == 0) {
          _saveDraftToLocal();
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _saveDraftToLocal() async {
    if (state.draft != null) {
      await ref.read(draftSessionServiceProvider).saveDraft(state.draft!);
    }
  }
}

final liveSessionControllerProvider = NotifierProvider<LiveSessionController, LiveSessionState>(() {
  return LiveSessionController();
});
