import 'package:dio/dio.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/auth_models.dart';

class AuthApi {
  AuthApi(ApiClient client) : _dio = client.dio;

  final Dio _dio;

  /// [cpf] só com dígitos.
  Future<LoginResponse> login({
    required String cpf,
    required String senha,
  }) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/clientes/login',
        data: {'cpf': cpf, 'senha': senha},
      );
      final login = LoginResponse.fromJson(resp.data ?? const {});
      if (login.token.isEmpty) {
        throw const ApiException(
          tipo: ApiErrorTipo.desconhecido,
          mensagem: ApiErrorMapper.msgDesconhecido,
        );
      }
      return login;
    } on DioException catch (e) {
      throw ApiErrorMapper.deDioException(e);
    }
  }

  Future<void> cadastrar(CadastroRequest request) async {
    try {
      await _dio.post<dynamic>('/clientes/register', data: request.toJson());
    } on DioException catch (e) {
      throw ApiErrorMapper.deDioException(e);
    }
  }
}
