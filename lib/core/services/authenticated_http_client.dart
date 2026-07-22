import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'token_storage_service.dart';
import '../../features/auth/services/auth_service.dart';

class UnauthorizedException implements Exception {
  final String message;
  const UnauthorizedException([this.message = 'Session expired. Please log in again.']);
  @override
  String toString() => message;
}

class AuthenticatedHttpClient {
  final TokenStorageService _tokenStorage;
  final AuthService _authService;
  VoidCallback? onUnauthorized;
  Completer<bool>? _refreshCompleter;

  AuthenticatedHttpClient(this._tokenStorage, this._authService);

  Future<Map<String, String>> _buildHeaders({
    Map<String, String>? extraHeaders,
    bool includeAuth = true,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (includeAuth) {
      final token = await _tokenStorage.getAccessToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    if (extraHeaders != null) headers.addAll(extraHeaders);
    return headers;
  }

  Future<bool> _tryRefresh() async {
    if (_refreshCompleter != null) return _refreshCompleter!.future;
    _refreshCompleter = Completer<bool>();
    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken == null) {
        _refreshCompleter!.complete(false);
        return false;
      }
      final tokens = await _authService.refreshAccessToken(refreshToken);
      await _tokenStorage.saveTokens(tokens.accessToken, tokens.refreshToken);
      _refreshCompleter!.complete(true);
      return true;
    } catch (e) {
      debugPrint('[AuthHttpClient] Refresh failed: $e');
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<http.Response> _executeRequest(
    Future<http.Response> Function(Map<String, String> headers) requestFn, {
    bool includeAuth = true,
    bool isRetry = false,
  }) async {
    final headers = await _buildHeaders(includeAuth: includeAuth);
    final response = await requestFn(headers);

    if (response.statusCode == 401 && includeAuth) {
      if (!isRetry) {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          return _executeRequest(requestFn, includeAuth: includeAuth, isRetry: true);
        }
      }
      onUnauthorized?.call();
      throw const UnauthorizedException();
    }
    return response;
  }

  Future<http.Response> get(Uri url, {Map<String, String>? extraHeaders, bool includeAuth = true}) {
    return _executeRequest(
      (headers) async => http.get(url, headers: {...headers, ...?extraHeaders}),
      includeAuth: includeAuth,
    );
  }

  Future<http.Response> post(
    Uri url, {
    Map<String, String>? extraHeaders,
    Object? body,
    Encoding? encoding,
    bool includeAuth = true,
    Duration? timeout,
  }) {
    return _executeRequest(
      (headers) async {
        final combined = {...headers, ...?extraHeaders};
        final future = http.post(url, headers: combined, body: body, encoding: encoding);
        return timeout != null ? future.timeout(timeout) : future;
      },
      includeAuth: includeAuth,
    );
  }

  Future<http.Response> put(
    Uri url, {
    Map<String, String>? extraHeaders,
    Object? body,
    Encoding? encoding,
    bool includeAuth = true,
  }) {
    return _executeRequest(
      (headers) async => http.put(url, headers: {...headers, ...?extraHeaders}, body: body, encoding: encoding),
      includeAuth: includeAuth,
    );
  }

  Future<http.Response> patch(
    Uri url, {
    Map<String, String>? extraHeaders,
    Object? body,
    Encoding? encoding,
    bool includeAuth = true,
  }) {
    return _executeRequest(
      (headers) async => http.patch(url, headers: {...headers, ...?extraHeaders}, body: body, encoding: encoding),
      includeAuth: includeAuth,
    );
  }

  Future<http.Response> delete(Uri url, {Map<String, String>? extraHeaders, bool includeAuth = true}) {
    return _executeRequest(
      (headers) async => http.delete(url, headers: {...headers, ...?extraHeaders}),
      includeAuth: includeAuth,
    );
  }
}

final authenticatedHttpClientProvider = Provider<AuthenticatedHttpClient>((ref) {
  return AuthenticatedHttpClient(
    ref.read(tokenStorageServiceProvider),
    ref.read(authServiceProvider),
  );
});
