import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda o JWT no armazenamento seguro, sempre na mesma chave.
class TokenStorage {
  TokenStorage(this._storage);

  /// Única chave usada para salvar, ler e apagar o token.
  static const String tokenKey = 'auth_token';

  final FlutterSecureStorage _storage;

  Future<void> saveToken(String token) =>
      _storage.write(key: tokenKey, value: token);

  Future<String?> getToken() => _storage.read(key: tokenKey);

  Future<void> clearToken() => _storage.delete(key: tokenKey);
}
