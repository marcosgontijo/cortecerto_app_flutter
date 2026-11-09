import 'package:dio/dio.dart';

import '../session/token_storage.dart';

/// Põe o `Authorization: Bearer <token>` nas requisições e avisa quando uma rota
/// protegida responde 401 (token inválido/expirado).
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStorage tokenStorage,
    required Future<void> Function() onUnauthorized,
  })  : _tokenStorage = tokenStorage,
        _onUnauthorized = onUnauthorized;

  /// Rotas públicas: não recebem token e um 401 nelas (ex.: senha errada)
  /// não significa sessão expirada.
  static const rotasPublicas = {'/clientes/login', '/clientes/register'};

  final TokenStorage _tokenStorage;
  final Future<void> Function() _onUnauthorized;

  static bool isPublica(String path) {
    final semQuery = path.split('?').first;
    return rotasPublicas.contains(semQuery);
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!isPublica(options.path)) {
      String? token;
      try {
        token = await _tokenStorage.getToken();
      } catch (_) {
        token = null;
      }
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 &&
        !isPublica(err.requestOptions.path)) {
      await _onUnauthorized();
    }
    handler.next(err);
  }
}
