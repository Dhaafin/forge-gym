import 'dart:async';
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
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return AuthTokensModel.fromJson(jsonDecode(response.body));
      } else {
        String? serverMessage;
        try {
          final data = jsonDecode(response.body);
          final detail = data['detail'];
          if (detail is List && detail.isNotEmpty) {
            serverMessage = detail[0]['msg'];
          } else if (detail is String) {
            serverMessage = detail;
          }
        } catch (_) {}

        if (response.statusCode == 401) {
          throw Exception(serverMessage ?? 'Incorrect email or password.');
        } else if (response.statusCode == 400 || response.statusCode == 422) {
          throw Exception(serverMessage ?? 'Invalid email or password format.');
        } else if (response.statusCode == 404) {
          throw Exception(serverMessage ?? 'Account not found.');
        } else if (response.statusCode >= 500) {
          throw Exception('Server error. Please try again later.');
        } else {
          throw Exception(serverMessage ?? 'Failed to login (Status: ${response.statusCode})');
        }
      }
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('SocketException') || errorStr.contains('Failed host lookup') || errorStr.contains('Connection refused')) {
        throw Exception('Cannot connect to the server. Please check your internet connection.');
      } else if (errorStr.contains('TimeoutException')) {
        throw Exception('Connection timed out. Please try again.');
      }
      throw Exception(errorStr.replaceAll('Exception: ', ''));
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
