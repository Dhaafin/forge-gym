import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/authenticated_http_client.dart';
import '../models/exercise_model.dart';
import '../models/workout_session_model.dart';

final workoutServiceProvider = Provider<WorkoutService>((ref) {
  return WorkoutService(ref.read(authenticatedHttpClientProvider));
});

class WorkoutService {
  final AuthenticatedHttpClient _client;

  WorkoutService(this._client);

  Future<List<ExerciseModel>> fetchExercises({
    String? search,
    String sortBy = 'name',
    String order = 'asc',
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final queryParams = {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'sort_by': sortBy,
        'order': order,
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/workouts/exercises')
          .replace(queryParameters: queryParams);

      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ExerciseModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch exercises. Code: ${response.statusCode}');
      }
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<ExerciseModel> createExercise({
    required String name,
    required String targetMuscle,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}/api/v1/workouts/exercises'),
        extraHeaders: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'target_muscle': targetMuscle,
        }),
      );

      if (response.statusCode == 201) {
        return ExerciseModel.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to create exercise. Code: ${response.statusCode}');
      }
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<ExerciseModel> updateExercise({
    required String exerciseId,
    required String name,
    required String targetMuscle,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/workouts/exercises/$exerciseId').replace(
        queryParameters: {
          'name': name,
          'target_muscle': targetMuscle,
        },
      );

      final response = await _client.put(uri);

      if (response.statusCode == 200) {
        return ExerciseModel.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to update exercise. Code: ${response.statusCode}');
      }
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> deleteExercise({
    required String exerciseId,
  }) async {
    try {
      final response = await _client.delete(
        Uri.parse('${ApiConstants.baseUrl}/api/v1/workouts/exercises/$exerciseId'),
      );

      if (response.statusCode == 204) {
        return;
      } else if (response.statusCode == 422) {
        final data = jsonDecode(response.body);
        final detail = data['detail'];
        String errorMsg = 'Validation/Restriction Error';
        if (detail is List && detail.isNotEmpty) {
          errorMsg = detail[0]['msg'] ?? errorMsg;
        } else if (detail is String) {
          errorMsg = detail;
        }
        throw Exception(errorMsg);
      } else {
        throw Exception('Failed to delete exercise. Code: ${response.statusCode}');
      }
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<WorkoutSessionModel> createWorkoutSession({
    required String title,
    required String startTime,
    required String endTime,
    required int durationMinutes,
    required List<Map<String, dynamic>> sets,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}/api/v1/workouts/session'),
        extraHeaders: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'start_time': startTime,
          'end_time': endTime,
          'duration_minutes': durationMinutes,
          'sets': sets,
        }),
        timeout: const Duration(seconds: 15),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return WorkoutSessionModel.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to create workout session. Code: ${response.statusCode}');
      }
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<List<WorkoutSessionModel>> fetchWorkoutHistory({
    String? search,
    String sortBy = 'start_time',
    String order = 'desc',
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final queryParams = {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'sort_by': sortBy,
        'order': order,
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/workouts/session/history')
          .replace(queryParameters: queryParams);

      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => WorkoutSessionModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch workout history. Code: ${response.statusCode}');
      }
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<WorkoutSessionModel> updateWorkoutSession({
    required String sessionId,
    required String title,
    required int durationMinutes,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/workouts/session/$sessionId').replace(
        queryParameters: {
          'title': title,
          'duration_minutes': durationMinutes.toString(),
        },
      );

      final response = await _client.put(uri);

      if (response.statusCode == 200) {
        return WorkoutSessionModel.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to update session. Code: ${response.statusCode}');
      }
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> deleteWorkoutSession({
    required String sessionId,
  }) async {
    try {
      final response = await _client.delete(
        Uri.parse('${ApiConstants.baseUrl}/api/v1/workouts/session/$sessionId'),
      );

      if (response.statusCode == 204) {
        return;
      } else {
        throw Exception('Failed to delete session. Code: ${response.statusCode}');
      }
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<WorkoutSetModel> updateWorkoutSet({
    required String setId,
    required double weightKg,
    required int reps,
    required String setType,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/workouts/set/$setId').replace(
        queryParameters: {
          'weight_kg': weightKg.toString(),
          'reps': reps.toString(),
          'set_type': setType,
        },
      );

      final response = await _client.put(uri);

      if (response.statusCode == 200) {
        return WorkoutSetModel.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to update workout set. Code: ${response.statusCode}');
      }
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> deleteWorkoutSet({
    required String setId,
  }) async {
    try {
      final response = await _client.delete(
        Uri.parse('${ApiConstants.baseUrl}/api/v1/workouts/set/$setId'),
      );

      if (response.statusCode == 204) {
        return;
      } else {
        throw Exception('Failed to delete workout set. Code: ${response.statusCode}');
      }
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
