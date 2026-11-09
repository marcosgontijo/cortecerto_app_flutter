import 'dart:io';

import 'package:dio/dio.dart';

enum ApiErrorTipo {
  dadosInvalidos, // 400
  naoAutorizado, // 401
  proibido, // 403
  naoEncontrado, // 404
  conflito, // 409
  bloqueado, // 423
  muitasTentativas, // 429
  servidor, // 5xx
  timeout,
  semConexao,
  desconhecido,
}

/// Erro de domínio da API, com mensagem amigável para mostrar ao usuário.
class ApiException implements Exception {
  const ApiException({
    required this.tipo,
    required this.mensagem,
    this.statusCode,
    this.errosPorCampo = const {},
  });

  final ApiErrorTipo tipo;
  final String mensagem;
  final int? statusCode;

  /// Erros de validação do backend (`errors.<campo>`), quando houver (400).
  final Map<String, String> errosPorCampo;

  @override
  String toString() => 'ApiException($tipo, $statusCode)';
}

/// Conversor central de [DioException] para [ApiException].
class ApiErrorMapper {
  ApiErrorMapper._();

  static const msgDadosInvalidos = 'Dados inválidos. Verifique os campos.';
  static const msgNaoAutorizado = 'Sessão expirada, faça login novamente';
  static const msgProibido = 'Você não tem permissão para esta ação.';
  static const msgNaoEncontrado = 'Recurso não encontrado.';
  static const msgConflito = 'Conflito com dados já existentes.';
  static const msgBloqueado =
      'Conta bloqueada temporariamente por excesso de tentativas. '
      'Tente novamente mais tarde.';
  static const msgMuitasTentativas =
      'Muitas tentativas. Aguarde alguns minutos e tente novamente.';
  static const msgServidor = 'Erro no servidor. Tente novamente mais tarde.';
  static const msgTimeout =
      'O servidor demorou para responder. Tente novamente.';
  static const msgSemConexao =
      'Sem conexão com o servidor. Verifique sua internet e tente novamente.';
  static const msgDesconhecido = 'Erro inesperado. Tente novamente.';

  static ApiException deErro(Object erro) {
    if (erro is ApiException) return erro;
    if (erro is DioException) return deDioException(erro);
    return const ApiException(
      tipo: ApiErrorTipo.desconhecido,
      mensagem: msgDesconhecido,
    );
  }

  static ApiException deDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          tipo: ApiErrorTipo.timeout,
          mensagem: msgTimeout,
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          tipo: ApiErrorTipo.semConexao,
          mensagem: msgSemConexao,
        );
      case DioExceptionType.badResponse:
        return _fromResponse(e.response);
      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          return const ApiException(
            tipo: ApiErrorTipo.semConexao,
            mensagem: msgSemConexao,
          );
        }
        if (e.response != null) return _fromResponse(e.response);
        return const ApiException(
          tipo: ApiErrorTipo.desconhecido,
          mensagem: msgDesconhecido,
        );
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
        return const ApiException(
          tipo: ApiErrorTipo.desconhecido,
          mensagem: msgDesconhecido,
        );
    }
  }

  static ApiException _fromResponse(Response<dynamic>? response) {
    final status = response?.statusCode;
    final data = response?.data;
    String? mensagemBackend;
    final campos = <String, String>{};
    if (data is Map) {
      final m = data['message'];
      if (m is String && m.trim().isNotEmpty) mensagemBackend = m.trim();
      final errors = data['errors'];
      if (errors is Map) {
        errors.forEach((k, v) {
          if (v != null) campos['$k'] = '$v';
        });
      }
    }

    switch (status) {
      case 400:
        return ApiException(
          tipo: ApiErrorTipo.dadosInvalidos,
          statusCode: 400,
          // Com erros por campo, a mensagem do backend junta todos ("campo: msg; ...")
          // e a tela mostra cada um embaixo do campo; a mensagem geral fica curta.
          mensagem: campos.isNotEmpty
              ? msgDadosInvalidos
              : (mensagemBackend ?? msgDadosInvalidos),
          errosPorCampo: campos,
        );
      case 401:
        return const ApiException(
          tipo: ApiErrorTipo.naoAutorizado,
          statusCode: 401,
          mensagem: msgNaoAutorizado,
        );
      case 403:
        return const ApiException(
          tipo: ApiErrorTipo.proibido,
          statusCode: 403,
          mensagem: msgProibido,
        );
      case 404:
        return const ApiException(
          tipo: ApiErrorTipo.naoEncontrado,
          statusCode: 404,
          mensagem: msgNaoEncontrado,
        );
      case 409:
        return ApiException(
          tipo: ApiErrorTipo.conflito,
          statusCode: 409,
          mensagem: mensagemBackend ?? msgConflito,
        );
      case 423:
        return const ApiException(
          tipo: ApiErrorTipo.bloqueado,
          statusCode: 423,
          mensagem: msgBloqueado,
        );
      case 429:
        return const ApiException(
          tipo: ApiErrorTipo.muitasTentativas,
          statusCode: 429,
          mensagem: msgMuitasTentativas,
        );
    }
    if (status != null && status >= 500) {
      return ApiException(
        tipo: ApiErrorTipo.servidor,
        statusCode: status,
        mensagem: msgServidor,
      );
    }
    return ApiException(
      tipo: ApiErrorTipo.desconhecido,
      statusCode: status,
      mensagem: msgDesconhecido,
    );
  }
}
