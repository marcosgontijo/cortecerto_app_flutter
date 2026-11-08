import 'package:dio/dio.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../domain/servico.dart';

class ServicosApi {
  ServicosApi(ApiClient client) : _dio = client.dio;

  final Dio _dio;

  Future<List<Servico>> listar() async {
    try {
      final resp = await _dio.get<List<dynamic>>('/servicos');
      return (resp.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Servico.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiErrorMapper.deDioException(e);
    }
  }
}
