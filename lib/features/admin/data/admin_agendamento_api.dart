import 'package:dio/dio.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/formatters/formatters.dart';
import '../../../core/network/api_client.dart';
import '../../agendamento/domain/status_agendamento.dart';
import '../domain/agendamento_admin.dart';

/// CRUD de agendamentos do admin (`/agendamento/admin/**`, só ADMIN).
class AdminAgendamentoApi {
  AdminAgendamentoApi(ApiClient client) : _dio = client.dio;

  final Dio _dio;

  /// Agenda do dia, ordenada por horário (o backend aceita filtrar por status).
  Future<List<AgendamentoAdmin>> listar(DateTime data, {StatusAgendamento? status}) async {
    try {
      final resp = await _dio.get<List<dynamic>>(
        '/agendamento/admin',
        queryParameters: {
          'data': Formatters.dataApi(data),
          if (status != null) 'status': status.api,
        },
      );
      return (resp.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AgendamentoAdmin.fromJson)
          .toList();
    } on DioException catch (e) {
      throw ApiErrorMapper.deDioException(e);
    }
  }

  Future<AgendamentoAdmin> criar({
    required int clienteId,
    required int servicoId,
    required DateTime data,
    required String horario,
    StatusAgendamento? status,
  }) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/agendamento/admin',
        data: {
          'clienteId': clienteId,
          'servicoId': servicoId,
          'data': Formatters.dataApi(data),
          'horario': horario,
          if (status != null) 'status': status.api,
        },
      );
      return AgendamentoAdmin.fromJson(resp.data ?? const {});
    } on DioException catch (e) {
      throw ApiErrorMapper.deDioException(e);
    }
  }

  /// Envia só os campos informados.
  Future<AgendamentoAdmin> atualizar(
    int id, {
    int? servicoId,
    DateTime? data,
    String? horario,
    StatusAgendamento? status,
  }) async {
    try {
      final resp = await _dio.put<Map<String, dynamic>>(
        '/agendamento/admin/$id',
        data: {
          'servicoId': ?servicoId,
          if (data != null) 'data': Formatters.dataApi(data),
          'horario': ?horario,
          if (status != null) 'status': status.api,
        },
      );
      return AgendamentoAdmin.fromJson(resp.data ?? const {});
    } on DioException catch (e) {
      throw ApiErrorMapper.deDioException(e);
    }
  }

  /// Cancela (libera o horário). Mesmo endpoint do cliente; o admin cancela qualquer um.
  Future<void> cancelar(int id) async {
    try {
      await _dio.put<dynamic>('/agendamento/$id/cancelar');
    } on DioException catch (e) {
      throw ApiErrorMapper.deDioException(e);
    }
  }

  Future<void> excluir(int id) async {
    try {
      await _dio.delete<dynamic>('/agendamento/admin/$id');
    } on DioException catch (e) {
      throw ApiErrorMapper.deDioException(e);
    }
  }
}
