import 'package:cortecerto_flutter/core/network/api_client.dart';
import 'package:cortecerto_flutter/core/session/jwt.dart';
import 'package:cortecerto_flutter/core/session/session_controller.dart';
import 'package:cortecerto_flutter/core/session/token_storage.dart';
import 'package:cortecerto_flutter/core/session/usuario.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  group('JwtPayload', () {
    test('lê claims e exp (segundos, base64url sem padding)', () {
      final exp = DateTime.utc(2030, 1, 1, 12);
      final p = JwtPayload.tryParse(criarJwt(id: 7, role: 'ADMIN', name: 'João', exp: exp))!;
      expect(p.id, 7);
      expect(p.role, 'ADMIN');
      expect(p.name, 'João');
      expect(p.exp, exp);
      expect(p.isExpired(DateTime.utc(2029, 12, 31)), isFalse);
      expect(p.isExpired(DateTime.utc(2030, 1, 1, 12)), isTrue);
    });

    test('token malformado ou sem exp', () {
      expect(JwtPayload.tryParse('abc'), isNull);
      expect(JwtPayload.tryParse('a.%%%.c'), isNull);
      expect(JwtPayload.tryParse(criarJwt(semExp: true))!.isExpired(DateTime.now()), isTrue);
    });
  });

  group('TokenStorage', () {
    test('salva, lê e apaga na MESMA chave', () async {
      FlutterSecureStorage.setMockInitialValues({});
      const storage = FlutterSecureStorage();
      final ts = TokenStorage(storage);
      await ts.saveToken('t1');
      expect(await storage.read(key: TokenStorage.tokenKey), 't1');
      expect(await ts.getToken(), 't1');
      await ts.clearToken();
      expect(await ts.getToken(), isNull);
      expect(await storage.readAll(), isEmpty);
    });
  });

  group('SessionController', () {
    test('restaura token válido', () async {
      final s = SessionController(FakeTokenStorage(criarJwt(name: 'Ana')));
      await s.restaurar();
      expect(s.status, SessionStatus.autenticada);
      expect(s.usuario!.nome, 'Ana');
    });

    test('token expirado → não autenticado e token apagado', () async {
      final storage = FakeTokenStorage(
          criarJwt(exp: DateTime.now().subtract(const Duration(minutes: 1))));
      final s = SessionController(storage);
      await s.restaurar();
      expect(s.status, SessionStatus.naoAutenticada);
      expect(storage.token, isNull);
    });

    test('sem token → não autenticado', () async {
      final s = SessionController(FakeTokenStorage());
      await s.restaurar();
      expect(s.isAutenticado, isFalse);
    });

    test('iniciar, sair e expirar', () async {
      final storage = FakeTokenStorage();
      final s = SessionController(storage);
      await s.iniciar('tok', const Usuario(id: 1, nome: 'A', role: 'CLIENTE'));
      expect(storage.token, 'tok');
      expect(s.isAutenticado, isTrue);

      await s.sair();
      expect(storage.token, isNull);
      expect(s.isAutenticado, isFalse);
      expect(s.mensagem, isNull);

      await s.iniciar('tok', const Usuario(id: 1, nome: 'A', role: 'CLIENTE'));
      await s.expirar();
      expect(storage.token, isNull);
      expect(s.mensagem, SessionController.mensagemSessaoExpirada);
    });
  });

  group('ApiClient / AuthInterceptor', () {
    test('envia Bearer nas rotas protegidas e não nas públicas', () async {
      final adapter = FakeHttpAdapter((_) => jsonResponse(<String, dynamic>{}, 200));
      final client = ApiClient(
        tokenStorage: FakeTokenStorage('abc'),
        onUnauthorized: () async {},
        baseUrl: 'http://teste/api',
        httpClientAdapter: adapter,
      );
      await client.dio.get<dynamic>('/servicos');
      await client.dio.post<dynamic>('/clientes/login', data: {});
      expect(adapter.requisicoes[0].headers['Authorization'], 'Bearer abc');
      expect(adapter.requisicoes[1].headers.containsKey('Authorization'), isFalse);
    });

    test('401 em rota protegida chama onUnauthorized; no login não', () async {
      var chamadas = 0;
      final client = ApiClient(
        tokenStorage: FakeTokenStorage('abc'),
        onUnauthorized: () async => chamadas++,
        baseUrl: 'http://teste/api',
        httpClientAdapter: FakeHttpAdapter((_) => jsonResponse({'status': 401}, 401)),
      );
      await expectLater(client.dio.get<dynamic>('/servicos'), throwsA(isA<DioException>()));
      expect(chamadas, 1);
      await expectLater(
          client.dio.post<dynamic>('/clientes/login', data: {}), throwsA(isA<DioException>()));
      expect(chamadas, 1);
    });
  });
}
