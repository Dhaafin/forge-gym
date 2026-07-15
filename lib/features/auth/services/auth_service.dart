import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../models/auth_tokens_model.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  final client = http.Client();
  ref.onDispose(() => client.close());
  return AuthService(client);
});

class AuthService {
  final http.Client _client;

  AuthService(this._client);

  Future<AuthTokensModel> login(String email, String password) async {
    try {
      final response = await _client.post(
        Uri.parse(ApiConstants.loginUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {
          'username': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        return AuthTokensModel.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 422) {
        final data = jsonDecode(response.body);
        final detail = data['detail'];
        String errorMsg = 'Validation Error';
        if (detail is List && detail.isNotEmpty) {
          errorMsg = detail[0]['msg'] ?? errorMsg;
        } else if (detail is String) {
          errorMsg = detail;
        }
        throw Exception(errorMsg);
      } else {
        throw Exception('Failed to login. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<AuthTokensModel> refreshAccessToken(String refreshToken) async {
    final response = await _client.post(
      Uri.parse(ApiConstants.refreshUrl),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'refresh_token': refreshToken}),
    );
    if (response.statusCode == 200) {
      return AuthTokensModel.fromJson(jsonDecode(response.body));
    }
    throw Exception('Refresh token invalid or expired.');
  }

  Future<void> logout(String refreshToken) async {
    try {
      await _client.post(
        Uri.parse(ApiConstants.logoutUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );
    } catch (_) {
      // Best-effort server-side revoke. Local logout must proceed
      // regardless of whether this network call succeeds.
    }
  }
}
