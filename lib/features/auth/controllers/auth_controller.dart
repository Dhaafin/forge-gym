import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/authenticated_http_client.dart';
import '../../../core/services/token_storage_service.dart';
import '../services/auth_service.dart';

final authControllerProvider = NotifierProvider<AuthController, AsyncValue<String?>>(AuthController.new);

class AuthController extends Notifier<AsyncValue<String?>> {
  @override
  AsyncValue<String?> build() {
    // Wire up the 401 handler: when any API call gets 401, auto-logout.
    final httpClient = ref.read(authenticatedHttpClientProvider);
    httpClient.onUnauthorized = _onUnauthorized;

    _checkToken();
    return const AsyncValue.loading();
  }

  /// Called automatically when any API call receives a 401 Unauthorized.
  void _onUnauthorized() {
    // Only trigger logout if we're currently authenticated (have a token).
    final current = state;
    if (current is AsyncData<String?> && current.value != null) {
      logout();
    }
  }

  Future<void> _checkToken() async {
    try {
      final tokenStorage = ref.read(tokenStorageServiceProvider);
      final token = await tokenStorage.getAccessToken();
      state = AsyncValue.data(token);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> login(String email, String password) async {
    final authService = ref.read(authServiceProvider);
    final tokens = await authService.login(email, password);
    final tokenStorage = ref.read(tokenStorageServiceProvider);
    await tokenStorage.saveTokens(tokens.accessToken, tokens.refreshToken);
    state = AsyncValue.data(tokens.accessToken);
  }

  Future<void> logout() async {
    final tokenStorage = ref.read(tokenStorageServiceProvider);
    try {
      final refreshToken = await tokenStorage.getRefreshToken();
      if (refreshToken != null) {
        await ref.read(authServiceProvider).logout(refreshToken);
      }
    } catch (_) {
      // Best-effort. Local logout must proceed regardless.
    }
    await tokenStorage.deleteTokens();
    state = const AsyncValue.data(null);
  }
}
