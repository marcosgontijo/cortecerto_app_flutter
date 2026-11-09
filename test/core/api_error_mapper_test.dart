import 'dart:io';

import 'package:cortecerto_flutter/core/errors/api_exception.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  test('400 com errors por campo', () {
    final e = ApiErrorMapper.deDioException(dioErro(400, {
      'status': 400,
      'message': 'cpf: CPF inválido; email: E-mail inválido',
      'errors': {'cpf': 'CPF inválido', 'email': 'E-mail inválido'},
    }));
    expect(e.tipo, ApiErrorTipo.dadosInvalidos);
    expect(e.statusCode, 400);
    expect(e.errosPorCampo, {'cpf': 'CPF inválido', 'email': 'E-mail inválido'});
    expect(e.mensagem, ApiErrorMapper.msgDadosInvalidos);
  });

  test('400 sem errors usa a mensagem do backend', () {
    final e = ApiErrorMapper.deDioException(
        dioErro(400, {'status': 400, 'message': 'Não é possível agendar em data/horário passado'}));
    expect(e.mensagem, 'Não é possível agendar em data/horário passado');
    expect(e.errosPorCampo, isEmpty);
  });

  test('401, 409, 423, 429 e 500', () {
    expect(ApiErrorMapper.deDioException(dioErro(401)).tipo, ApiErrorTipo.naoAutorizado);
    expect(ApiErrorMapper.deDioException(dioErro(401)).mensagem, 'Sessão expirada, faça login novamente');
    final c = ApiErrorMapper.deDioException(dioErro(409, {'status': 409, 'message': 'Horário indisponível'}));
    expect(c.tipo, ApiErrorTipo.conflito);
    expect(c.mensagem, 'Horário indisponível');
    expect(ApiErrorMapper.deDioException(dioErro(423)).mensagem, ApiErrorMapper.msgBloqueado);
    expect(ApiErrorMapper.deDioException(dioErro(429)).mensagem, ApiErrorMapper.msgMuitasTentativas);
    expect(ApiErrorMapper.deDioException(dioErro(500)).tipo, ApiErrorTipo.servidor);
  });

  test('timeout e sem conexão', () {
    final req = RequestOptions(path: '/x');
    for (final t in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
    ]) {
      expect(ApiErrorMapper.deDioException(DioException(requestOptions: req, type: t)).tipo,
          ApiErrorTipo.timeout);
    }
    expect(
      ApiErrorMapper.deDioException(
          DioException(requestOptions: req, type: DioExceptionType.connectionError)).mensagem,
      ApiErrorMapper.msgSemConexao,
    );
    expect(
      ApiErrorMapper.deDioException(DioException(
              requestOptions: req,
              type: DioExceptionType.unknown,
              error: const SocketException('falhou')))
          .tipo,
      ApiErrorTipo.semConexao,
    );
  });

  test('deErro mantém ApiException e trata erro qualquer', () {
    const original = ApiException(tipo: ApiErrorTipo.conflito, mensagem: 'x');
    expect(ApiErrorMapper.deErro(original), same(original));
    expect(ApiErrorMapper.deErro(StateError('x')).tipo, ApiErrorTipo.desconhecido);
  });
}
