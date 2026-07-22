import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/authenticated_http_client.dart';
import '../models/user_profile_model.dart';

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(ref.read(authenticatedHttpClientProvider));
});

class ProfileService {
  final AuthenticatedHttpClient _client;

  ProfileService(this._client);

  static final _meUri = Uri.parse('${ApiConstants.baseUrl}/api/v1/users/me');

  Future<UserProfileModel> fetchProfile() async {
    try {
      final response = await _client.get(_meUri);
      if (response.statusCode == 200) {
        return UserProfileModel.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }
      throw Exception('Failed to fetch profile. Code: ${response.statusCode}');
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<UserProfileModel> updateProfile({
    String? name,
    String? preferredUnit,
    double? weightKg,
    double? heightCm,
    String? fitnessGoal,
    String? experienceLevel,
    String? injuriesOrLimitations,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (preferredUnit != null) body['preferred_unit'] = preferredUnit;
      if (weightKg != null) body['weight_kg'] = weightKg;
      if (heightCm != null) body['height_cm'] = heightCm;
      if (fitnessGoal != null) body['fitness_goal'] = fitnessGoal;
      if (experienceLevel != null) body['experience_level'] = experienceLevel;
      // Allow explicit null to clear the field
      if (injuriesOrLimitations != null) {
        body['injuries_or_limitations'] = injuriesOrLimitations.isEmpty
            ? null
            : injuriesOrLimitations;
      }

      final response = await _client.patch(
        _meUri,
        extraHeaders: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return UserProfileModel.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }

      if (response.statusCode == 422) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final detail = data['detail'];
        String errorMsg = 'Validation error';
        if (detail is List && detail.isNotEmpty) {
          errorMsg = detail[0]['msg'] as String? ?? errorMsg;
        } else if (detail is String) {
          errorMsg = detail;
        }
        throw Exception(errorMsg);
      }

      throw Exception('Failed to update profile. Code: ${response.statusCode}');
    } on UnauthorizedException {
      rethrow;
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }
}
