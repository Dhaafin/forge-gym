import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  final client = http.Client();
  ref.onDispose(() => client.close());
  return AuthService(client);
});

class AuthService {
  final http.Client _client;

  AuthService(this._client);

  Future<String> login(String email, String password) async {
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
        final data = jsonDecode(response.body);
        final token = data['access_token'] as String?;
        if (token != null) {
          return token;
        }
        throw Exception('Token not found in response');
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
}
