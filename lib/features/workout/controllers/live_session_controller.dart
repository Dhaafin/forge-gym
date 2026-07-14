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
    // Attempt to load draft on initialization
    _loadDraft();
    return LiveSessionState();
  }

  Future<void> _loadDraft() async {
    final service = ref.read(draftSessionServiceProvider);
    final draft = await service.loadDraft();
    if (draft != null) {
      state = state.copyWith(draft: draft);
      if (draft.isLive) {
        // Calculate elapsed time based on start time
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

    // Calculate set number for this exercise
    final currentSets = state.draft!.sets;
    final exerciseSets = currentSets.where((s) => s.exerciseId == exercise.id).toList();
    final nextSetNumber = exerciseSets.length + 1;

    final newSet = WorkoutSetModel(
      id: _uuid.v4(),
      sessionId: state.draft!.id, // temporary
      exerciseId: exercise.id,
      exerciseName: exercise.name,
      setNumber: nextSetNumber,
      weightKg: weightKg,
      reps: reps,
      setType: setType,
      isPr: false, // PR logic is handled backend-side normally, default to false
    );

    final updatedSets = List<WorkoutSetModel>.from(currentSets)..add(newSet);
    
    state = state.copyWith(
      draft: state.draft!.copyWith(sets: updatedSets),
    );
    _saveDraftToLocal();
  }

  void deleteSet(String setId) {
    if (state.draft == null) return;

    final currentSets = state.draft!.sets;
    final updatedSets = currentSets.where((s) => s.id != setId).toList();

    // Re-number remaining sets for the same exercise? Usually, we might just leave them,
    // or re-number. Let's re-number for consistency.
    // However, it's complex because we need to know the exercise ID of the deleted set.
    // For simplicity right now, we just remove it. Re-numbering can be added later if needed.
    
    state = state.copyWith(
      draft: state.draft!.copyWith(sets: updatedSets),
    );
    _saveDraftToLocal();
  }

  Future<bool> finishWorkout() async {
    if (state.draft == null) return false;

    _timer?.cancel();
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Safely extract token — AsyncValue.value returns null if loading/error state.
      // Use whenData or check the state directly.
      final authState = ref.read(authControllerProvider);
      final token = authState.asData?.value;
      debugPrint('[LiveSession] Submitting workout. Token present: ${token != null}');

      final draft = state.draft!;
      final endTime = draft.isLive ? DateTime.now() : (draft.endTime ?? DateTime.now());

      int durationMinutes = draft.durationMinutes ?? 0;
      if (draft.isLive) {
        durationMinutes = endTime.difference(draft.startTime).inMinutes;
      }

      final setsJson = draft.sets.map((s) => {
        'exercise_id': s.exerciseId,
        'set_number': s.setNumber,
        'weight_kg': s.weightKg,
        'reps': s.reps,
        'set_type': s.setType,
      }).toList();

      debugPrint('[LiveSession] Sending ${setsJson.length} sets to API.');

      final workoutService = ref.read(workoutServiceProvider);
      await workoutService.createWorkoutSession(
        title: draft.title,
        startTime: draft.startTime.toUtc().toIso8601String(),
        endTime: endTime.toUtc().toIso8601String(),
        durationMinutes: durationMinutes,
        sets: setsJson,
        token: token,
      );

      // Successfully saved
      await ref.read(draftSessionServiceProvider).clearDraft();

      // Refresh history
      ref.read(workoutHistoryControllerProvider.notifier).fetchFirstPage();

      state = LiveSessionState(); // Reset state
      return true;
    } catch (e) {
      debugPrint('[LiveSession] finishWorkout failed: $e');
      final errorMessage = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(isLoading: false, error: errorMessage);
      if (state.draft?.isLive == true) {
        _startTimer(); // resume timer on fail
      }
      return false;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.draft != null) {
        final elapsed = DateTime.now().difference(state.draft!.startTime);
        state = state.copyWith(elapsedTime: elapsed);
        
        // Auto-save every 30 seconds
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
