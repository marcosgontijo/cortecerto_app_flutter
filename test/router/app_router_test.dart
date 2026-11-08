import 'package:cortecerto_flutter/app.dart';
import 'package:cortecerto_flutter/core/network/api_client.dart';
import 'package:cortecerto_flutter/core/session/session_controller.dart';
import 'package:cortecerto_flutter/core/session/usuario.dart';
import 'package:cortecerto_flutter/features/agendamento/data/agendamento_api.dart';
import 'package:cortecerto_flutter/features/auth/data/auth_api.dart';
import 'package:cortecerto_flutter/features/auth/domain/auth_models.dart';
import 'package:cortecerto_flutter/features/servicos/data/servicos_api.dart';
import 'package:cortecerto_flutter/features/servicos/domain/servico.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes.dart';

void main() {
  late FakeTokenStorage storage;
  late SessionController session;
  late MockAuthApi authApi;
  late MockServicosApi servicosApi;
  late MockAgendamentoApi agendamentoApi;

  setUp(() {
    authApi = MockAuthApi();
    servicosApi = MockServicosApi();
    agendamentoApi = MockAgendamentoApi();
    when(() => servicosApi.listar()).thenAnswer((_) async => const [
          Servico(id: 1, tipoServico: 'Corte Simples', descricao: 'd', precoServico: '35.00'),
        ]);
  });

  Future<void> abrir(WidgetTester tester, {String? token, String? local}) async {
    storage = FakeTokenStorage(token);
    session = SessionController(storage);
    await session.restaurar();
    await tester.pumpWidget(CorteCertoApp(
      deps: AppDependencies(
        session: session,
        authApi: authApi,
        servicosApi: servicosApi,
        agendamentoApi: agendamentoApi,
      ),
      localInicial: local,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('sem token → /login (mesmo pedindo rota protegida)', (tester) async {
    await abrir(tester, local: '/servicos');
    expect(find.text('Bem-vindo'), findsOneWidget);
  });

  testWidgets('token expirado → /login', (tester) async {
    await abrir(tester,
        token: criarJwt(exp: DateTime.now().subtract(const Duration(hours: 1))),
        local: '/servicos');
    expect(find.text('Bem-vindo'), findsOneWidget);
    expect(storage.token, isNull);
  });

  testWidgets('CLIENTE com token válido → /servicos', (tester) async {
    await abrir(tester, token: criarJwt(name: 'Maria'));
    expect(find.text('Olá, Maria!'), findsOneWidget);
    expect(find.text('Corte Simples'), findsOneWidget);
  });

  testWidgets('ADMIN → /admin', (tester) async {
    await abrir(tester, token: criarJwt(role: 'ADMIN', name: 'Chefe'));
    expect(find.text('Painel Admin'), findsOneWidget);
    expect(find.text('Olá, Chefe!'), findsOneWidget);
  });

  testWidgets('CLIENTE tentando /admin → /servicos', (tester) async {
    await abrir(tester, token: criarJwt(), local: '/admin');
    expect(find.text('Painel Admin'), findsNothing);
    expect(find.text('Serviços'), findsOneWidget);
  });

  testWidgets('login com sucesso navega por role; logout volta ao login', (tester) async {
    when(() => authApi.login(cpf: '52998224725', senha: 'abc12345')).thenAnswer((_) async =>
        LoginResponse(
            token: criarJwt(),
            usuario: const Usuario(id: 3, nome: 'Maria', role: 'CLIENTE')));
    await abrir(tester);
    await tester.enterText(find.byKey(const Key('campo-cpf')), '52998224725');
    await tester.enterText(find.byKey(const Key('campo-senha')), 'abc12345');
    await tester.tap(find.byKey(const Key('botao-entrar')));
    await tester.pumpAndSettle();
    expect(find.text('Olá, Maria!'), findsOneWidget);

    await tester.tap(find.byKey(const Key('botao-sair')));
    await tester.pumpAndSettle();
    expect(find.text('Bem-vindo'), findsOneWidget);
    expect(storage.token, isNull);
  });

  testWidgets('401 numa chamada protegida → /login com aviso', (tester) async {
    storage = FakeTokenStorage(criarJwt());
    session = SessionController(storage);
    await session.restaurar();
    final client = ApiClient(
      tokenStorage: storage,
      onUnauthorized: session.expirar,
      baseUrl: 'http://teste/api',
      httpClientAdapter: FakeHttpAdapter(
          (_) => jsonResponse({'status': 401, 'message': 'Token inválido ou expirado'}, 401)),
    );
    await tester.pumpWidget(CorteCertoApp(
      deps: AppDependencies(
        session: session,
        authApi: AuthApi(client),
        servicosApi: ServicosApi(client),
        agendamentoApi: AgendamentoApi(client),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Bem-vindo'), findsOneWidget);
    expect(find.text('Sessão expirada, faça login novamente'), findsOneWidget);
    expect(storage.token, isNull);
  });
}
