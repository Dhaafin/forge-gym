import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../models/exercise_model.dart';

class WorkoutService {
  Future<List<ExerciseModel>> fetchExercises({
    String? search,
    String sortBy = 'name',
    String order = 'asc',
    int limit = 20,
    int offset = 0,
    String? token,
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

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ExerciseModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch exercises. Code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
