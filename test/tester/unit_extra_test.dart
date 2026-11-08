// Testes extras do TESTER (FASE 2): bordas de JWT, mapper de erros, interceptor,
// redirect, formatadores, APIs reais com HTTP falso e TokenStorage com a chave única.
import 'dart:convert';
import 'dart:io';

import 'package:cortecerto_flutter/core/config/api_config.dart';
import 'package:cortecerto_flutter/core/errors/api_exception.dart';
import 'package:cortecerto_flutter/core/formatters/formatters.dart';
import 'package:cortecerto_flutter/core/network/api_client.dart';
import 'package:cortecerto_flutter/core/network/auth_interceptor.dart';
import 'package:cortecerto_flutter/core/router/app_router.dart';
import 'package:cortecerto_flutter/core/router/rotas.dart';
import 'package:cortecerto_flutter/core/session/jwt.dart';
import 'package:cortecerto_flutter/core/session/session_controller.dart';
import 'package:cortecerto_flutter/core/session/token_storage.dart';
import 'package:cortecerto_flutter/core/session/usuario.dart';
import 'package:cortecerto_flutter/features/agendamento/data/agendamento_api.dart';
import 'package:cortecerto_flutter/features/auth/data/auth_api.dart';
import 'package:cortecerto_flutter/features/auth/domain/auth_models.dart';
import 'package:cortecerto_flutter/features/auth/presentation/cadastro_controller.dart';
import 'package:cortecerto_flutter/features/auth/presentation/login_controller.dart';
import 'package:cortecerto_flutter/features/servicos/data/servicos_api.dart';
import 'package:cortecerto_flutter/features/servicos/domain/servico.dart';
import 'package:cortecerto_flutter/features/servicos/presentation/servicos_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// TokenStorage que falha (ex.: Keystore corrompido).
class TokenStorageQuebrado extends FakeTokenStorage {
  @override
  Future<String?> getToken() async => throw Exception('keystore');
  @override
  Future<void> clearToken() async => throw Exception('keystore');
}

String _jwtCru(Object payload) {
  String b64(String s) => base64Url.encode(utf8.encode(s)).replaceAll('=', '');
  return '${b64('{"alg":"HS256"}')}.${b64(payload is String ? payload : jsonEncode(payload))}.sig';
}

ApiClient _client(FakeHttpAdapter adapter, {TokenStorage? storage, Future<void> Function()? on401}) =>
    ApiClient(
      tokenStorage: storage ?? FakeTokenStorage('tok'),
      onUnauthorized: on401 ?? () async {},
      baseUrl: 'http://teste/api',
      httpClientAdapter: adapter,
    );

void main() {
  setUpAll(() async => initializeDateFormatting('pt_BR'));

  group('ApiConfig', () {
    test('sem --dart-define o padrão é http://10.0.2.2:8080/api', () {
      expect(ApiConfig.defaultBaseUrl, 'http://10.0.2.2:8080/api');
      expect(ApiConfig.baseUrl, ApiConfig.defaultBaseUrl);
    });

    test('ApiClient usa a baseUrl recebida e timeouts definidos', () {
      final c = ApiClient(
          tokenStorage: FakeTokenStorage(), onUnauthorized: () async {}, baseUrl: 'http://x:1/api');
      expect(c.dio.options.baseUrl, 'http://x:1/api');
      expect(c.dio.options.connectTimeout, isNotNull);
      expect(c.dio.options.receiveTimeout, isNotNull);
      // nenhum LogInterceptor (vazaria token/CPF/senha no console)
      expect(c.dio.interceptors.whereType<LogInterceptor>(), isEmpty);
    });
  });

  group('JwtPayload (bordas)', () {
    test('exp exatamente agora conta como expirado; 1s antes não', () {
      final exp = DateTime.utc(2030, 1, 1, 12);
      final p = JwtPayload.tryParse(_jwtCru({'exp': exp.millisecondsSinceEpoch ~/ 1000}))!;
      expect(p.isExpired(exp), isTrue);
      expect(p.isExpired(exp.subtract(const Duration(seconds: 1))), isFalse);
      // hora local convertida para UTC
      expect(p.isExpired(exp.toLocal().subtract(const Duration(seconds: 1))), isFalse);
    });

    test('payload não-JSON, JSON lista, base64 inválido e partes erradas → null', () {
      expect(JwtPayload.tryParse(_jwtCru('nao json')), isNull);
      expect(JwtPayload.tryParse(_jwtCru([1, 2])), isNull);
      expect(JwtPayload.tryParse('a.%%%.c'), isNull);
      expect(JwtPayload.tryParse('a.b'), isNull);
      expect(JwtPayload.tryParse(''), isNull);
    });

    test('exp como double e id vindo de sub', () {
      final p = JwtPayload.tryParse(_jwtCru({'exp': 1893456000.0, 'sub': '42', 'role': 'ADMIN'}))!;
      expect(p.id, 42);
      expect(p.exp, DateTime.fromMillisecondsSinceEpoch(1893456000000, isUtc: true));
      expect(p.role, 'ADMIN');
    });

    test('payload com acentos (UTF-8) no nome', () {
      final p = JwtPayload.tryParse(criarJwt(name: 'João Ação'))!;
      expect(p.name, 'João Ação');
    });
  });

  group('SessionController (bordas)', () {
    test('token sem exp ou malformado → Login e token apagado', () async {
      for (final t in [criarJwt(semExp: true), 'lixo']) {
        final st = FakeTokenStorage(t);
        final s = SessionController(st);
        await s.restaurar();
        expect(s.isAutenticado, isFalse, reason: t);
        expect(st.token, isNull, reason: t);
        expect(st.clears, 1);
      }
    });

    test('relógio injetado: expira exatamente no exp', () async {
      final exp = DateTime.utc(2030, 1, 1);
      final token = criarJwt(exp: exp);
      final antes = SessionController(FakeTokenStorage(token),
          agora: () => exp.subtract(const Duration(minutes: 1)));
      await antes.restaurar();
      expect(antes.isAutenticado, isTrue);
      final depois = SessionController(FakeTokenStorage(token), agora: () => exp);
      await depois.restaurar();
      expect(depois.isAutenticado, isFalse);
    });

    test('storage quebrado não trava restaurar nem sair', () async {
      final s = SessionController(TokenStorageQuebrado());
      await s.restaurar();
      expect(s.isAutenticado, isFalse);
      await s.iniciar('t', const Usuario(id: 1, nome: 'a', role: 'CLIENTE'));
      await s.sair();
      expect(s.isAutenticado, isFalse);
    });

    test('expirar sem sessão não mostra aviso; restaurar ADMIN', () async {
      final s = SessionController(FakeTokenStorage());
      await s.expirar();
      expect(s.mensagem, isNull);
      final a = SessionController(FakeTokenStorage(criarJwt(role: 'ADMIN')));
      await a.restaurar();
      expect(a.usuario!.isAdmin, isTrue);
    });
  });

  group('TokenStorage (chave única)', () {
    test('save/get/clear usam só a chave auth_token', () async {
      final sec = MockSecureStorage();
      when(() => sec.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});
      when(() => sec.read(key: any(named: 'key'))).thenAnswer((_) async => 'x');
      when(() => sec.delete(key: any(named: 'key'))).thenAnswer((_) async {});
      final ts = TokenStorage(sec);
      await ts.saveToken('x');
      await ts.getToken();
      await ts.clearToken();
      verify(() => sec.write(key: 'auth_token', value: 'x')).called(1);
      verify(() => sec.read(key: 'auth_token')).called(1);
      verify(() => sec.delete(key: 'auth_token')).called(1);
      verifyNoMoreInteractions(sec);
    });
  });

  group('AuthInterceptor (bordas)', () {
    test('sem token não manda Authorization; storage com erro também não', () async {
      final a = FakeHttpAdapter((_) => jsonResponse([], 200));
      await _client(a, storage: FakeTokenStorage()).dio.get<dynamic>('/servicos');
      await _client(a, storage: FakeTokenStorage('')).dio.get<dynamic>('/servicos');
      await _client(a, storage: TokenStorageQuebrado()).dio.get<dynamic>('/servicos');
      for (final r in a.requisicoes) {
        expect(r.headers.containsKey('Authorization'), isFalse);
      }
    });

    test('register não recebe token; 401 no register não expira sessão', () async {
      var n = 0;
      final a = FakeHttpAdapter((_) => jsonResponse({'status': 401}, 401));
      final c = _client(a, on401: () async => n++);
      await expectLater(c.dio.post<dynamic>('/clientes/register', data: {}),
          throwsA(isA<DioException>()));
      expect(a.requisicoes.single.headers.containsKey('Authorization'), isFalse);
      expect(n, 0);
    });

    test('403/500 em rota protegida não derrubam a sessão; 401 em /agendamento sim', () async {
      var n = 0;
      var status = 403;
      final c = _client(FakeHttpAdapter((_) => jsonResponse({}, status)), on401: () async => n++);
      await expectLater(c.dio.get<dynamic>('/servicos'), throwsA(isA<DioException>()));
      status = 500;
      await expectLater(c.dio.get<dynamic>('/servicos'), throwsA(isA<DioException>()));
      expect(n, 0);
      status = 401;
      await expectLater(c.dio.post<dynamic>('/agendamento', data: {}), throwsA(isA<DioException>()));
      await expectLater(c.dio.get<dynamic>('/agendamento/disponibilidades?data=2030-01-01'),
          throwsA(isA<DioException>()));
      expect(n, 2);
    });

    test('isPublica com query string', () {
      expect(AuthInterceptor.isPublica('/clientes/login?x=1'), isTrue);
      expect(AuthInterceptor.isPublica('/servicos'), isFalse);
    });
  });

  group('ApiErrorMapper (bordas)', () {
    DioException tipo(DioExceptionType t, {Object? error}) =>
        DioException(requestOptions: RequestOptions(path: '/x'), type: t, error: error);

    test('send/receive timeout, connectionError, SocketException e cancel', () {
      expect(ApiErrorMapper.deDioException(tipo(DioExceptionType.sendTimeout)).tipo,
          ApiErrorTipo.timeout);
      expect(ApiErrorMapper.deDioException(tipo(DioExceptionType.receiveTimeout)).mensagem,
          ApiErrorMapper.msgTimeout);
      expect(ApiErrorMapper.deDioException(tipo(DioExceptionType.connectionError)).tipo,
          ApiErrorTipo.semConexao);
      expect(
          ApiErrorMapper.deDioException(
                  tipo(DioExceptionType.unknown, error: const SocketException('x')))
              .tipo,
          ApiErrorTipo.semConexao);
      expect(ApiErrorMapper.deDioException(tipo(DioExceptionType.cancel)).tipo,
          ApiErrorTipo.desconhecido);
    });

    test('403, 404, 503, 418 e corpo não-JSON', () {
      expect(ApiErrorMapper.deDioException(dioErro(403)).tipo, ApiErrorTipo.proibido);
      expect(ApiErrorMapper.deDioException(dioErro(404)).tipo, ApiErrorTipo.naoEncontrado);
      expect(ApiErrorMapper.deDioException(dioErro(503, '<html>')).tipo, ApiErrorTipo.servidor);
      expect(ApiErrorMapper.deDioException(dioErro(418)).tipo, ApiErrorTipo.desconhecido);
      final e = ApiErrorMapper.deDioException(dioErro(400, 'texto puro'));
      expect(e.mensagem, ApiErrorMapper.msgDadosInvalidos);
      expect(e.errosPorCampo, isEmpty);
    });

    test('400: errors com valor null é ignorado; 409 usa mensagem do backend', () {
      final e = ApiErrorMapper.deDioException(dioErro(400, {
        'status': 400,
        'message': 'cpf: inválido',
        'errors': {'cpf': 'CPF inválido', 'email': null}
      }));
      expect(e.errosPorCampo, {'cpf': 'CPF inválido'});
      expect(ApiErrorMapper.deDioException(dioErro(409, {'message': 'Horário indisponível'})).mensagem,
          'Horário indisponível');
      expect(ApiErrorMapper.deDioException(dioErro(409, {'message': '  '})).mensagem,
          ApiErrorMapper.msgConflito);
    });

    test('mensagem amigável não contém o corpo cru do backend no 401/423/429', () {
      for (final s in [401, 423, 429]) {
        final e = ApiErrorMapper.deDioException(dioErro(s, {'message': 'stack interno'}));
        expect(e.mensagem, isNot(contains('stack interno')));
      }
    });

    test('toString não expõe dados', () {
      const e = ApiException(
          tipo: ApiErrorTipo.dadosInvalidos, mensagem: 'm', errosPorCampo: {'cpf': '52998224725'});
      expect(e.toString(), isNot(contains('52998224725')));
    });
  });

  group('redirecionarPorSessao (tabela)', () {
    Future<SessionController> sessao(String? role) async {
      final s = SessionController(FakeTokenStorage());
      if (role != null) await s.iniciar('t', Usuario(id: 1, nome: 'n', role: role));
      return s;
    }

    test('sem sessão', () async {
      final s = await sessao(null);
      expect(redirecionarPorSessao(s, Rotas.login), isNull);
      expect(redirecionarPorSessao(s, Rotas.cadastro), isNull);
      for (final r in [
        Rotas.servicos,
        Rotas.agendamento,
        Rotas.agendamentoConfirmado,
        Rotas.produtos,
        Rotas.admin,
        '/',
        '/qualquer'
      ]) {
        expect(redirecionarPorSessao(s, r), Rotas.login, reason: r);
      }
    });

    test('CLIENTE', () async {
      final s = await sessao('CLIENTE');
      expect(redirecionarPorSessao(s, Rotas.login), Rotas.servicos);
      expect(redirecionarPorSessao(s, Rotas.cadastro), Rotas.servicos);
      expect(redirecionarPorSessao(s, Rotas.admin), Rotas.servicos);
      for (final r in [Rotas.servicos, Rotas.agendamento, Rotas.agendamentoConfirmado, Rotas.produtos]) {
        expect(redirecionarPorSessao(s, r), isNull, reason: r);
      }
    });

    test('ADMIN (role em minúsculas também)', () async {
      for (final role in ['ADMIN', 'admin']) {
        final s = await sessao(role);
        expect(redirecionarPorSessao(s, Rotas.login), Rotas.admin);
        expect(redirecionarPorSessao(s, Rotas.admin), isNull);
        expect(redirecionarPorSessao(s, Rotas.servicos), Rotas.admin);
        expect(redirecionarPorSessao(s, Rotas.produtos), Rotas.admin);
      }
    });

    test('rotas nomeadas exigidas pela TAREFA', () {
      expect({
        Rotas.login,
        Rotas.cadastro,
        Rotas.servicos,
        Rotas.agendamento,
        Rotas.agendamentoConfirmado,
        Rotas.produtos,
        Rotas.admin
      }, {
        '/login',
        '/cadastro',
        '/servicos',
        '/agendamento',
        '/agendamento/confirmado',
        '/produtos',
        '/admin'
      });
    });
  });

  group('Formatters', () {
    test('moeda e preço texto', () {
      expect(Formatters.moeda(25), r'R$ 25,00');
      expect(Formatters.moeda(1234.5), r'R$ 1.234,50');
      expect(Formatters.precoTexto('35.00'), r'R$ 35,00');
      expect(Formatters.precoTexto('35,5'), r'R$ 35,50');
      expect(Formatters.precoTexto(null), 'Preço a consultar');
      expect(Formatters.precoTexto('abc'), 'abc');
    });

    test('datas', () {
      expect(Formatters.data(DateTime(2030, 1, 5)), '05/01/2030');
      expect(Formatters.dataApi(DateTime(2030, 1, 5, 23, 59)), '2030-01-05');
    });
  });

  group('APIs reais com HTTP falso (contrato do app)', () {
    test('login envia {cpf, senha} e lê {token,id,name,role}', () async {
      final a = FakeHttpAdapter((_) =>
          jsonResponse({'token': 'jwt', 'id': 7, 'name': 'Ana', 'role': 'CLIENTE'}, 200));
      final r = await AuthApi(_client(a)).login(cpf: '52998224725', senha: 'abc12345');
      expect(a.requisicoes.single.path, '/clientes/login');
      expect(a.requisicoes.single.data, {'cpf': '52998224725', 'senha': 'abc12345'});
      expect(r.token, 'jwt');
      expect(r.usuario.id, 7);
      expect(r.usuario.nome, 'Ana');
    });

    test('login 200 sem token vira erro (não inicia sessão vazia)', () async {
      final a = FakeHttpAdapter((_) => jsonResponse({'id': 1}, 200));
      await expectLater(AuthApi(_client(a)).login(cpf: '1', senha: '2'),
          throwsA(isA<ApiException>()));
    });

    test('login 401/423/429 viram ApiException com tipo correto', () async {
      for (final (s, t) in [
        (401, ApiErrorTipo.naoAutorizado),
        (423, ApiErrorTipo.bloqueado),
        (429, ApiErrorTipo.muitasTentativas)
      ]) {
        final a = FakeHttpAdapter((_) => jsonResponse({'status': s, 'message': 'm'}, s));
        await expectLater(AuthApi(_client(a)).login(cpf: '1', senha: '2'),
            throwsA(isA<ApiException>().having((e) => e.tipo, 'tipo', t)));
      }
    });

    test('cadastro envia os 7 campos e 400 traz errors por campo', () async {
      final a = FakeHttpAdapter((_) => jsonResponse({
            'status': 400,
            'message': 'x',
            'errors': {'cpf': 'CPF inválido', 'email': 'E-mail inválido'}
          }, 400));
      const req = CadastroRequest(
          nome: 'N',
          telefone: '11987654321',
          cpf: '52998224725',
          email: 'a@b.com',
          dataNascimento: '1990-03-15',
          senha: 'abc12345',
          confirmarSenha: 'abc12345');
      await expectLater(
          AuthApi(_client(a)).cadastrar(req),
          throwsA(isA<ApiException>().having((e) => e.errosPorCampo, 'campos',
              {'cpf': 'CPF inválido', 'email': 'E-mail inválido'})));
      final body = a.requisicoes.single.data as Map;
      expect(body.keys.toSet(),
          {'nome', 'telefone', 'cpf', 'email', 'dataNascimento', 'senha', 'confirmarSenha'});
      expect(body.containsKey('role'), isFalse, reason: 'app não deve mandar role');
    });

    test('serviços: lista null-safe', () async {
      final a = FakeHttpAdapter((_) => jsonResponse([
            {'id': 1, 'tipoServico': 'Barba', 'descricao': null, 'precoServico': '25.00'},
            {'id': '2', 'tipoServico': 'X'},
            'lixo',
          ], 200));
      final l = await ServicosApi(_client(a)).listar();
      expect(l.length, 2);
      expect(l[0].descricao, isNull);
      expect(l[1].id, 2);
      expect(a.requisicoes.single.headers['Authorization'], 'Bearer tok');
    });

    test('disponibilidades usa ?data=AAAA-MM-DD; agendar envia {data,horario,servico}', () async {
      final a = FakeHttpAdapter((o) => o.method == 'GET'
          ? jsonResponse(['08:00', '08:30'], 200)
          : jsonResponse({'id': 1}, 200));
      final api = AgendamentoApi(_client(a));
      expect(await api.disponibilidades(DateTime(2030, 3, 7)), ['08:00', '08:30']);
      expect(a.requisicoes[0].path, '/agendamento/disponibilidades');
      expect(a.requisicoes[0].queryParameters, {'data': '2030-03-07'});
      await api.agendar(
          data: DateTime(2030, 3, 7),
          horario: '08:30',
          servico: const Servico(id: 1, tipoServico: 'Barba', descricao: 'd', precoServico: '25.00'));
      expect(a.requisicoes[1].data, {
        'data': '2030-03-07',
        'horario': '08:30',
        'servico': {'tipoServico': 'Barba', 'descricao': 'd', 'precoServico': '25.00'}
      });
    });

    test('agendar 409 e 400 viram ApiException', () async {
      for (final s in [409, 400]) {
        final a = FakeHttpAdapter((_) => jsonResponse({'status': s, 'message': 'msg $s'}, s));
        await expectLater(
            AgendamentoApi(_client(a)).agendar(
                data: DateTime(2030), horario: '08:00', servico: const Servico(id: 1, tipoServico: 'B')),
            throwsA(isA<ApiException>()
                .having((e) => e.statusCode, 's', s)
                .having((e) => e.mensagem, 'm', 'msg $s')));
      }
    });
  });

  group('Controllers (bordas)', () {
    late MockAuthApi auth;
    setUpAll(() => registerFallbackValue(const CadastroRequest(
        nome: '', telefone: '', cpf: '', email: '', dataNascimento: '', senha: '', confirmarSenha: '')));
    setUp(() => auth = MockAuthApi());

    test('Login: timeout e sem conexão mostram mensagem própria e não iniciam sessão', () async {
      final session = SessionController(FakeTokenStorage());
      final c = LoginController(auth, session);
      for (final (t, m) in [
        (ApiErrorTipo.timeout, ApiErrorMapper.msgTimeout),
        (ApiErrorTipo.semConexao, ApiErrorMapper.msgSemConexao)
      ]) {
        when(() => auth.login(cpf: any(named: 'cpf'), senha: any(named: 'senha')))
            .thenThrow(ApiException(tipo: t, mensagem: m));
        expect(await c.entrar(cpf: '1', senha: '2'), isFalse);
        expect(c.erro, m);
        expect(c.isLoading, isFalse);
        expect(session.isAutenticado, isFalse);
      }
    });

    test('Login: erro não-ApiException vira mensagem genérica', () async {
      when(() => auth.login(cpf: any(named: 'cpf'), senha: any(named: 'senha')))
          .thenThrow(StateError('x'));
      final c = LoginController(auth, SessionController(FakeTokenStorage()));
      expect(await c.entrar(cpf: '1', senha: '2'), isFalse);
      expect(c.erro, ApiErrorMapper.msgDesconhecido);
    });

    test('Cadastro: editar campo limpa só o erro dele', () async {
      when(() => auth.cadastrar(any())).thenThrow(const ApiException(
          tipo: ApiErrorTipo.dadosInvalidos,
          mensagem: 'm',
          errosPorCampo: {'cpf': 'a', 'email': 'b'}));
      final c = CadastroController(auth);
      await c.cadastrar(const CadastroRequest(
          nome: '', telefone: '', cpf: '', email: '', dataNascimento: '', senha: '', confirmarSenha: ''));
      c.limparErroDoCampo('cpf');
      expect(c.erroDoCampo('cpf'), isNull);
      expect(c.erroDoCampo('email'), 'b');
    });

    test('Serviços: erro e depois sucesso limpa o erro', () async {
      final api = MockServicosApi();
      final c = ServicosController(api);
      when(() => api.listar()).thenThrow(
          const ApiException(tipo: ApiErrorTipo.semConexao, mensagem: ApiErrorMapper.msgSemConexao));
      await c.carregarServicos();
      expect(c.erro, ApiErrorMapper.msgSemConexao);
      expect(c.isVazio, isFalse);
      when(() => api.listar()).thenAnswer((_) async => const [Servico(id: 1, tipoServico: 'B')]);
      await c.carregarServicos();
      expect(c.erro, isNull);
      expect(c.servicos.length, 1);
    });
  });
}
