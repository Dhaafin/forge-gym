import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TokenStorageService {
  final FlutterSecureStorage _storage;
  static const String _tokenKey = 'auth_token';

  TokenStorageService(this._storage);

  /// Stores the JWT token securely.
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Retrieves the secured JWT token.
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Deletes the secured JWT token.
  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }
}

/// Global provider for the secure token storage service.
final tokenStorageServiceProvider = Provider<TokenStorageService>((ref) {
  return TokenStorageService(const FlutterSecureStorage());
});
