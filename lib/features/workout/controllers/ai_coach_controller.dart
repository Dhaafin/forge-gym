import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_coach_analysis_model.dart';
import '../services/workout_service.dart';

enum AiCoachStatus { idle, loading, success, error }

class AiCoachState {
  final AiCoachStatus status;
  final double progress; // 0.0 to 1.0
  final String loadingMessage;
  final AiCoachAnalysisModel? data;
  final String? errorMessage;

  AiCoachState({
    this.status = AiCoachStatus.idle,
    this.progress = 0.0,
    this.loadingMessage = '',
    this.data,
    this.errorMessage,
  });

  AiCoachState copyWith({
    AiCoachStatus? status,
    double? progress,
    String? loadingMessage,
    AiCoachAnalysisModel? data,
    String? errorMessage,
    bool clearData = false,
    bool clearError = false,
  }) {
    return AiCoachState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      loadingMessage: loadingMessage ?? this.loadingMessage,
      data: clearData ? null : (data ?? this.data),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AiCoachController extends Notifier<Map<String, AiCoachState>> {
  final Map<String, Timer?> _timers = {};

  @override
  Map<String, AiCoachState> build() {
    ref.onDispose(() {
      for (final timer in _timers.values) {
        timer?.cancel();
      }
      _timers.clear();
    });
    return const {};
  }

  Future<void> fetchAnalysis(String sessionId) async {
    final currentMap = Map<String, AiCoachState>.from(state);
    final currentState = currentMap[sessionId] ?? AiCoachState();

    if (currentState.status == AiCoachStatus.loading) return;

    _timers[sessionId]?.cancel();
    
    currentMap[sessionId] = AiCoachState(
      status: AiCoachStatus.loading,
      progress: 0.0,
      loadingMessage: 'Initializing AI Coach...',
    );
    state = currentMap;

    // List of gamified steps
    final steps = [
      _LoadingStep(0.0, 0.25, 'Analyzing workout structure...'),
      _LoadingStep(0.25, 0.55, 'Evaluating sets, reps & intensity...'),
      _LoadingStep(0.55, 0.80, 'Calculating progressive overload...'),
      _LoadingStep(0.80, 0.95, 'Formulating coaching tips...'),
    ];

    double currentProgress = 0.0;
    int currentStepIndex = 0;

    _timers[sessionId] = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      final updatedMap = Map<String, AiCoachState>.from(state);
      final sessionState = updatedMap[sessionId];
      if (sessionState == null) {
        timer.cancel();
        return;
      }

      if (currentProgress < 0.95) {
        currentProgress += 0.02;
        if (currentProgress > 0.95) currentProgress = 0.95;

        // Determine correct loading message based on progress
        for (int i = 0; i < steps.length; i++) {
          if (currentProgress >= steps[i].start && currentProgress <= steps[i].end) {
            currentStepIndex = i;
            break;
          }
        }

        updatedMap[sessionId] = sessionState.copyWith(
          progress: currentProgress,
          loadingMessage: steps[currentStepIndex].message,
        );
        state = updatedMap;
      }
    });

    try {
      final workoutService = ref.read(workoutServiceProvider);
      final analysis = await workoutService.fetchAiCoachAnalysis(sessionId: sessionId);

      _timers[sessionId]?.cancel();
      _timers.remove(sessionId);

      final updatedMap = Map<String, AiCoachState>.from(state);
      final sessionState = updatedMap[sessionId] ?? AiCoachState();

      // Fast forward progress to 100%
      updatedMap[sessionId] = sessionState.copyWith(
        progress: 1.0,
        loadingMessage: 'Analysis complete!',
      );
      state = updatedMap;

      await Future.delayed(const Duration(milliseconds: 300));

      final finalMap = Map<String, AiCoachState>.from(state);
      final finalSessionState = finalMap[sessionId] ?? AiCoachState();
      finalMap[sessionId] = finalSessionState.copyWith(
        status: AiCoachStatus.success,
        data: analysis,
      );
      state = finalMap;
    } catch (e) {
      _timers[sessionId]?.cancel();
      _timers.remove(sessionId);

      final updatedMap = Map<String, AiCoachState>.from(state);
      final sessionState = updatedMap[sessionId] ?? AiCoachState();
      updatedMap[sessionId] = sessionState.copyWith(
        status: AiCoachStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      state = updatedMap;
    }
  }

  void reset(String sessionId) {
    _timers[sessionId]?.cancel();
    _timers.remove(sessionId);

    final updatedMap = Map<String, AiCoachState>.from(state);
    updatedMap.remove(sessionId);
    state = updatedMap;
  }
}

class _LoadingStep {
  final double start;
  final double end;
  final String message;

  _LoadingStep(this.start, this.end, this.message);
}

final aiCoachNotifierProvider = NotifierProvider<AiCoachController, Map<String, AiCoachState>>(
  AiCoachController.new,
);
