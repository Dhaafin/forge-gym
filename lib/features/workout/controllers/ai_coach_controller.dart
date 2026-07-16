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

class AiCoachNotifier extends FamilyNotifier<AiCoachState, String> {
  Timer? _progressTimer;

  @override
  AiCoachState build(String arg) {
    ref.onDispose(() {
      _progressTimer?.cancel();
    });
    return AiCoachState();
  }

  Future<void> fetchAnalysis() async {
    final sessionId = arg;
    if (state.status == AiCoachStatus.loading) return;

    _progressTimer?.cancel();
    state = AiCoachState(
      status: AiCoachStatus.loading,
      progress: 0.0,
      loadingMessage: 'Initializing AI Coach...',
    );

    // List of gamified steps
    final steps = [
      _LoadingStep(0.0, 0.25, 'Analyzing workout structure...'),
      _LoadingStep(0.25, 0.55, 'Evaluating sets, reps & intensity...'),
      _LoadingStep(0.55, 0.80, 'Calculating progressive overload...'),
      _LoadingStep(0.80, 0.95, 'Formulating coaching tips...'),
    ];

    double currentProgress = 0.0;
    int currentStepIndex = 0;

    _progressTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
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

        state = state.copyWith(
          progress: currentProgress,
          loadingMessage: steps[currentStepIndex].message,
        );
      }
    });

    try {
      final workoutService = ref.read(workoutServiceProvider);
      final analysis = await workoutService.fetchAiCoachAnalysis(sessionId: sessionId);

      _progressTimer?.cancel();

      // Fast forward progress to 100%
      state = state.copyWith(
        progress: 1.0,
        loadingMessage: 'Analysis complete!',
      );

      await Future.delayed(const Duration(milliseconds: 300));

      state = state.copyWith(
        status: AiCoachStatus.success,
        data: analysis,
      );
    } catch (e) {
      _progressTimer?.cancel();
      state = state.copyWith(
        status: AiCoachStatus.error,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void reset() {
    _progressTimer?.cancel();
    state = AiCoachState();
  }
}

class _LoadingStep {
  final double start;
  final double end;
  final String message;

  _LoadingStep(this.start, this.end, this.message);
}

final aiCoachNotifierProvider = NotifierProvider.family<AiCoachNotifier, AiCoachState, String>(() {
  return AiCoachNotifier();
});
