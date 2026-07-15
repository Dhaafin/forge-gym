import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'token_storage_service.dart';

/// Exception thrown when the server responds with 401 Unauthorized.
/// This signals that the token has expired and the user must re-authenticate.
class UnauthorizedException implements Exception {
  final String message;
  const UnauthorizedException([this.message = 'Session expired. Please log in again.']);

  @override
  String toString() => message;
}

/// A centralized HTTP client that automatically:
/// 1. Reads the JWT token from SharedPreferences
/// 2. Injects the Authorization: Bearer header into every request
/// 3. Detects 401 Unauthorized responses and triggers logout
///
/// This eliminates the need to pass tokens manually through controllers and services.
class AuthenticatedHttpClient {
  final TokenStorageService _tokenStorage;

  /// Optional callback invoked when a 401 is detected.
  /// The AuthController sets this during initialization to trigger logout.
  VoidCallback? onUnauthorized;

  AuthenticatedHttpClient(this._tokenStorage);

  /// Retrieves the stored JWT token, or null if not present.
  Future<String?> _getToken() async {
    return await _tokenStorage.getToken();
  }

  /// Builds the standard headers, injecting Bearer token if available.
  Future<Map<String, String>> _buildHeaders({
    Map<String, String>? extraHeaders,
    bool includeAuth = true,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = await _getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  /// Checks for 401 and triggers the logout callback.
  /// Returns true if a 401 was detected.
  bool _handle401(http.Response response) {
    if (response.statusCode == 401) {
      debugPrint('[AuthHttpClient] 401 Unauthorized detected. Triggering logout.');
      onUnauthorized?.call();
      return true;
    }
    return false;
  }

  /// Performs a GET request with automatic auth header injection.
  Future<http.Response> get(
    Uri url, {
    Map<String, String>? extraHeaders,
    bool includeAuth = true,
  }) async {
    final headers = await _buildHeaders(extraHeaders: extraHeaders, includeAuth: includeAuth);
    final response = await http.get(url, headers: headers);
    if (_handle401(response)) {
      throw const UnauthorizedException();
    }
    return response;
  }

  /// Performs a POST request with automatic auth header injection.
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? extraHeaders,
    Object? body,
    Encoding? encoding,
    bool includeAuth = true,
    Duration? timeout,
  }) async {
    final headers = await _buildHeaders(extraHeaders: extraHeaders, includeAuth: includeAuth);
    var response = await (timeout != null
        ? http.post(url, headers: headers, body: body, encoding: encoding).timeout(timeout)
        : http.post(url, headers: headers, body: body, encoding: encoding));
    if (_handle401(response)) {
      throw const UnauthorizedException();
    }
    return response;
  }

  /// Performs a PUT request with automatic auth header injection.
  Future<http.Response> put(
    Uri url, {
    Map<String, String>? extraHeaders,
    Object? body,
    Encoding? encoding,
    bool includeAuth = true,
  }) async {
    final headers = await _buildHeaders(extraHeaders: extraHeaders, includeAuth: includeAuth);
    final response = await http.put(url, headers: headers, body: body, encoding: encoding);
    if (_handle401(response)) {
      throw const UnauthorizedException();
    }
    return response;
  }

  /// Performs a DELETE request with automatic auth header injection.
  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? extraHeaders,
    bool includeAuth = true,
  }) async {
    final headers = await _buildHeaders(extraHeaders: extraHeaders, includeAuth: includeAuth);
    final response = await http.delete(url, headers: headers);
    if (_handle401(response)) {
      throw const UnauthorizedException();
    }
    return response;
  }
}

/// Global Riverpod provider for the authenticated HTTP client.
/// This is a singleton that persists across the app lifecycle.
final authenticatedHttpClientProvider = Provider<AuthenticatedHttpClient>((ref) {
  return AuthenticatedHttpClient(ref.read(tokenStorageServiceProvider));
});
