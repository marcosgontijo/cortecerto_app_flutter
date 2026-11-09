import 'package:dio/dio.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/agendamento_admin.dart';

/// Busca de clientes do admin (`GET /clientes?busca=`, no máximo 20, CPF mascarado).
class ClientesApi {
  ClientesApi(ApiClient client) : _dio = client.dio;

  final Dio _dio;

  Future<List<ClienteResumo>> buscar(String termo) async {
    try {
      final resp = await _dio.get<List<dynamic>>(
        '/clientes',
        queryParameters: {'busca': termo.trim()},
      );
      return (resp.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ClienteResumo.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiErrorMapper.deDioException(e);
    }
  }
}
