import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authControllerProvider = NotifierProvider<AuthController, AsyncValue<String?>>(AuthController.new);

class AuthController extends Notifier<AsyncValue<String?>> {
  static const String _tokenKey = 'auth_token';

  @override
  AsyncValue<String?> build() {
    _checkToken();
    return const AsyncValue.loading();
  }

  Future<void> _checkToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      state = AsyncValue.data(token);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final authService = ref.read(authServiceProvider);
      final token = await authService.login(email, password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      state = AsyncValue.data(token);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
