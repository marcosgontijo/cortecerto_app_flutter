// FASE 3 (developer): rotas /admin/** e /meus-agendamentos, isPublica exata e senha só com [A-Za-z].
import 'package:cortecerto_flutter/app.dart';
import 'package:cortecerto_flutter/core/network/auth_interceptor.dart';
import 'package:cortecerto_flutter/core/router/app_router.dart';
import 'package:cortecerto_flutter/core/router/rotas.dart';
import 'package:cortecerto_flutter/core/session/session_controller.dart';
import 'package:cortecerto_flutter/core/session/usuario.dart';
import 'package:cortecerto_flutter/core/validators/validators.dart';
import 'package:cortecerto_flutter/features/meus_agendamentos/presentation/meus_agendamentos_page.dart';
import 'package:cortecerto_flutter/features/servicos/domain/servico.dart';
import 'package:cortecerto_flutter/features/servicos/presentation/servicos_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes.dart';

void main() {
  setUpAll(() => registerFallbackValue(DateTime(2030)));

  group('redirecionarPorSessao com /admin/** e /meus-agendamentos', () {
    Future<SessionController> sessao(String? role) async {
      final s = SessionController(FakeTokenStorage());
      if (role != null) await s.iniciar('t', Usuario(id: 1, nome: 'n', role: role));
      return s;
    }

    test('ADMIN navega em /admin/**; fora dele vai para /admin', () async {
      final s = await sessao('ADMIN');
      for (final r in [Rotas.admin, Rotas.adminAgenda, Rotas.adminAgendamentoForm, '/admin/qualquer']) {
        expect(redirecionarPorSessao(s, r), isNull, reason: r);
      }
      for (final r in [Rotas.meusAgendamentos, Rotas.servicos, '/administrador', '/adminx']) {
        expect(redirecionarPorSessao(s, r), Rotas.admin, reason: r);
      }
    });

    test('CLIENTE bloqueado em /admin e em tudo abaixo; acessa /meus-agendamentos', () async {
      final s = await sessao('CLIENTE');
      for (final r in [Rotas.admin, Rotas.adminAgenda, Rotas.adminAgendamentoForm, '/admin/x/y']) {
        expect(redirecionarPorSessao(s, r), Rotas.servicos, reason: r);
      }
      expect(redirecionarPorSessao(s, Rotas.meusAgendamentos), isNull);
    });

    test('sem sessão: rotas novas vão para o login', () async {
      final s = await sessao(null);
      for (final r in [Rotas.adminAgenda, Rotas.adminAgendamentoForm, Rotas.meusAgendamentos]) {
        expect(redirecionarPorSessao(s, r), Rotas.login, reason: r);
      }
    });

    test('caminhos das rotas novas', () {
      expect(Rotas.adminAgenda, '/admin/agenda');
      expect(Rotas.meusAgendamentos, '/meus-agendamentos');
      expect(Rotas.isAdmin('/admin'), isTrue);
      expect(Rotas.isAdmin('/admin/agenda'), isTrue);
      expect(Rotas.isAdmin('/adminagenda'), isFalse);
    });
  });

  group('App inteiro (router real)', () {
    late MockAdminAgendamentoApi adminApi;
    late MockAgendamentoApi agendamentoApi;
    late MockServicosApi servicosApi;

    setUp(() {
      adminApi = MockAdminAgendamentoApi();
      agendamentoApi = MockAgendamentoApi();
      servicosApi = MockServicosApi();
      when(() => adminApi.listar(any())).thenAnswer((_) async => []);
      when(() => agendamentoApi.meus()).thenAnswer((_) async => []);
      when(() => servicosApi.listar())
          .thenAnswer((_) async => const [Servico(id: 1, tipoServico: 'Corte Simples')]);
    });

    Future<void> abrir(WidgetTester tester, String token, String local) async {
      final session = SessionController(FakeTokenStorage(token));
      await session.restaurar();
      await tester.pumpWidget(CorteCertoApp(
        deps: AppDependencies(
          session: session,
          authApi: MockAuthApi(),
          servicosApi: servicosApi,
          agendamentoApi: agendamentoApi,
          adminAgendamentoApi: adminApi,
          clientesApi: MockClientesApi(),
        ),
        localInicial: local,
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('ADMIN abre /admin/agenda direto', (tester) async {
      await abrir(tester, criarJwt(role: 'ADMIN'), Rotas.adminAgenda);
      expect(find.text('Agenda - Hoje'), findsOneWidget);
      verify(() => adminApi.listar(any())).called(1);
    });

    testWidgets('ADMIN: Painel → card Agenda → voltar ao Painel', (tester) async {
      await abrir(tester, criarJwt(role: 'ADMIN', name: 'Chefe'), Rotas.admin);
      await tester.tap(find.byKey(const Key('card-agenda')));
      await tester.pumpAndSettle();
      expect(find.text('Agenda - Hoje'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Painel Admin'), findsOneWidget);
    });

    testWidgets('ADMIN em /meus-agendamentos → /admin', (tester) async {
      await abrir(tester, criarJwt(role: 'ADMIN'), Rotas.meusAgendamentos);
      expect(find.text('Painel Admin'), findsOneWidget);
    });

    testWidgets('CLIENTE em /admin/agenda e /admin/agenda/form → /servicos', (tester) async {
      for (final r in [Rotas.adminAgenda, Rotas.adminAgendamentoForm]) {
        await abrir(tester, criarJwt(), r);
        expect(find.text('Painel Admin'), findsNothing, reason: r);
        expect(find.text('Serviços'), findsOneWidget, reason: r);
        // FASE 4: o rótulo 'Serviços' se repete na NavigationBar das 3 telas do cliente;
        // a tela de destino passa a ser identificada pelo tipo.
        expect(find.byType(ServicosPage), findsOneWidget, reason: r);
      }
      verifyNever(() => adminApi.listar(any()));
    });

    testWidgets('CLIENTE: Serviços → Meus agendamentos (carrega do servidor) → voltar', (tester) async {
      await abrir(tester, criarJwt(name: 'Maria'), Rotas.servicos);
      await tester.tap(find.byKey(const Key('botao-meus-agendamentos')));
      await tester.pumpAndSettle();
      expect(find.text('Meus agendamentos'), findsOneWidget);
      // FASE 4: o texto também é rótulo da NavigationBar; confirma a tela pelo tipo.
      expect(find.byType(MeusAgendamentosPage), findsOneWidget);
      expect(find.byType(ServicosPage), findsNothing);
      verify(() => agendamentoApi.meus()).called(1);
      await tester.tap(find.byKey(const Key('botao-voltar')));
      await tester.pumpAndSettle();
      expect(find.text('Olá, Maria!'), findsOneWidget);
    });

    testWidgets('ADMIN abrindo o formulário sem argumentos → /admin/agenda', (tester) async {
      await abrir(tester, criarJwt(role: 'ADMIN'), Rotas.adminAgendamentoForm);
      expect(find.text('Agenda - Hoje'), findsOneWidget);
    });
  });

  test('isPublica compara o path exato (não endsWith)', () {
    expect(AuthInterceptor.isPublica('/clientes/login'), isTrue);
    expect(AuthInterceptor.isPublica('/clientes/register?x=1'), isTrue);
    expect(AuthInterceptor.isPublica('/outra/clientes/login'), isFalse);
    expect(AuthInterceptor.isPublica('/admin/clientes/register'), isFalse);
    expect(AuthInterceptor.isPublica('/clientes/login/extra'), isFalse);
  });

  test('senha: letra acentuada não conta como letra (igual ao backend [A-Za-z])', () {
    expect(Validators.senha('ééééé123'), contains('letras e números'));
    expect(Validators.senha('çãõ12345'), contains('letras e números'));
    expect(Validators.senha('ééééé12a'), isNull);
  });
}
