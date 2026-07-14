import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../auth/controllers/auth_controller.dart';
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
  /// Returns `false` on failure. State will have `isLoading: false` and
  /// an [error] message set.
  Future<bool> finishWorkout() async {
    if (state.draft == null) return false;

    _timer?.cancel();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final token = ref.read(authControllerProvider).asData?.value;
      debugPrint('[LiveSession] Token present: ${token != null}');

      final draft = state.draft!;
      final endTime = draft.isLive ? DateTime.now() : (draft.endTime ?? DateTime.now());
      final durationMinutes = draft.isLive
          ? endTime.difference(draft.startTime).inMinutes
          : (draft.durationMinutes ?? 0);

      final setsJson = draft.sets.map((s) => {
        'exercise_id': s.exerciseId,
        'set_number': s.setNumber,
        'weight_kg': s.weightKg,
        'reps': s.reps,
        'set_type': s.setType,
      }).toList();

      debugPrint('[LiveSession] Sending ${setsJson.length} sets.');

      final newSession = await ref.read(workoutServiceProvider).createWorkoutSession(
        title: draft.title,
        startTime: draft.startTime.toUtc().toIso8601String(),
        endTime: endTime.toUtc().toIso8601String(),
        durationMinutes: durationMinutes,
        sets: setsJson,
        token: token,
      );

      // Clear persisted draft and add the new session locally (best practice).
      // Do NOT touch in-memory draft here — the UI caller navigates first,
      // then calls resetState() to clean up.
      await ref.read(draftSessionServiceProvider).clearDraft();
      ref.read(workoutHistoryControllerProvider.notifier).addSession(newSession);

      debugPrint('[LiveSession] Workout saved successfully.');
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      debugPrint('[LiveSession] finishWorkout failed: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      // Resume timer if this was a live session.
      if (state.draft?.isLive == true) _startTimer();
      return false;
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
