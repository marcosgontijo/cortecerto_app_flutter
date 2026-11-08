import 'package:dio/dio.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/formatters/formatters.dart';
import '../../../core/network/api_client.dart';
import '../../servicos/domain/servico.dart';

class AgendamentoApi {
  AgendamentoApi(ApiClient client) : _dio = client.dio;

  final Dio _dio;

  /// Horários livres (`HH:mm`) do dia.
  Future<List<String>> disponibilidades(DateTime data) async {
    try {
      final resp = await _dio.get<List<dynamic>>(
        '/agendamento/disponibilidades',
        queryParameters: {'data': Formatters.dataApi(data)},
      );
      return (resp.data ?? const []).map((h) => '$h').toList();
    } on DioException catch (e) {
      throw ApiErrorMapper.deDioException(e);
    }
  }

  Future<void> agendar({
    required DateTime data,
    required String horario,
    required Servico servico,
  }) async {
    try {
      await _dio.post<dynamic>(
        '/agendamento',
        data: {
          'data': Formatters.dataApi(data),
          'horario': horario,
          'servico': servico.toAgendamentoJson(),
        },
      );
    } on DioException catch (e) {
      throw ApiErrorMapper.deDioException(e);
    }
  }
}
