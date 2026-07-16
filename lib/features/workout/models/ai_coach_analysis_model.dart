class AiCoachAnalysisModel {
  final String id;
  final String userId;
  final String sessionId;
  final String prompt;
  final String response;
  final String modelUsed;
  final int tokensPrompt;
  final int tokensCompletion;
  final DateTime createdAt;

  AiCoachAnalysisModel({
    required this.id,
    required this.userId,
    required this.sessionId,
    required this.prompt,
    required this.response,
    required this.modelUsed,
    required this.tokensPrompt,
    required this.tokensCompletion,
    required this.createdAt,
  });

  factory AiCoachAnalysisModel.fromJson(Map<String, dynamic> json) {
    return AiCoachAnalysisModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      response: json['response'] as String? ?? '',
      modelUsed: json['model_used'] as String? ?? '',
      tokensPrompt: json['tokens_prompt'] as int? ?? 0,
      tokensCompletion: json['tokens_completion'] as int? ?? 0,
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now() 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'session_id': sessionId,
      'prompt': prompt,
      'response': response,
      'model_used': modelUsed,
      'tokens_prompt': tokensPrompt,
      'tokens_completion': tokensCompletion,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
