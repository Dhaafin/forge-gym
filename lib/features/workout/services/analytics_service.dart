import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/authenticated_http_client.dart';
import '../models/analytics_model.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService(ref.read(authenticatedHttpClientProvider));
});

class AnalyticsService {
  final AuthenticatedHttpClient _client;

  AnalyticsService(this._client);

  Future<AnalyticsOverview> fetchOverview({required String range}) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/analytics/overview')
          .replace(queryParameters: {'range': range});

      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        return AnalyticsOverview.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }
      throw Exception('Failed to fetch analytics overview. Code: ${response.statusCode}');
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<ExerciseProgression> fetchExerciseProgression({
    required String exerciseId,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiConstants.baseUrl}/api/v1/analytics/exercise/$exerciseId',
      );

      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        return ExerciseProgression.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }
      throw Exception('Failed to fetch exercise progression. Code: ${response.statusCode}');
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
