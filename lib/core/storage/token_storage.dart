import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  final _storage = const FlutterSecureStorage();

  static const _key = 'auth_token';

  Future<void> saveToken(String token) async {
    await _storage.write(key: _key, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _key);
  }

  Future<void> clear() async {
    await _storage.delete(key: _key);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: 'jwt_token');
  }

}
