import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_coach_analysis_model.dart';
import '../services/workout_service.dart';

final aiCoachAnalysisProvider = FutureProvider.family<AiCoachAnalysisModel, String>((ref, sessionId) async {
  final workoutService = ref.watch(workoutServiceProvider);
  return workoutService.fetchAiCoachAnalysis(sessionId: sessionId);
});
