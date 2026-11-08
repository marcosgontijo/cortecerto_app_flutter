import 'dart:convert';
import 'dart:typed_data';

import 'package:cortecerto_flutter/core/session/token_storage.dart';
import 'package:cortecerto_flutter/features/agendamento/data/agendamento_api.dart';
import 'package:cortecerto_flutter/features/auth/data/auth_api.dart';
import 'package:cortecerto_flutter/features/servicos/data/servicos_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthApi extends Mock implements AuthApi {}

class MockServicosApi extends Mock implements ServicosApi {}

class MockAgendamentoApi extends Mock implements AgendamentoApi {}

/// TokenStorage em memória (sem plugin), registrando as chamadas.
class FakeTokenStorage extends TokenStorage {
  FakeTokenStorage([this.token]) : super(const FlutterSecureStorage());

  String? token;
  int clears = 0;

  @override
  Future<void> saveToken(String token) async => this.token = token;

  @override
  Future<String?> getToken() async => token;

  @override
  Future<void> clearToken() async {
    clears++;
    token = null;
  }
}

/// Monta um JWT (sem assinatura válida) com as claims do backend.
String criarJwt({
  int id = 3,
  String role = 'CLIENTE',
  String name = 'Maria',
  DateTime? exp,
  bool semExp = false,
}) {
  String b64(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final expira = exp ?? DateTime.now().add(const Duration(hours: 8));
  final payload = <String, dynamic>{
    'id': id,
    'role': role,
    'name': name,
    'sub': '$id',
    'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    if (!semExp) 'exp': expira.millisecondsSinceEpoch ~/ 1000,
  };
  return '${b64({'alg': 'HS256', 'typ': 'JWT'})}.${b64(payload)}.assinatura';
}

/// Adapter HTTP falso para o Dio: responde com o que [responder] devolver.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.responder);

  final ResponseBody Function(RequestOptions options) responder;
  final List<RequestOptions> requisicoes = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requisicoes.add(options);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Object? body, int status) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// DioException de resposta com status e corpo (para simular erros da API).
DioException dioErro(int status, [Object? body]) {
  final req = RequestOptions(path: '/x');
  return DioException(
    requestOptions: req,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(requestOptions: req, statusCode: status, data: body),
  );
}
