// FASE 5 (developer): rota /admin/faturamento (só ADMIN) com o router real.
import 'package:cortecerto_flutter/app.dart';
import 'package:cortecerto_flutter/core/router/app_router.dart';
import 'package:cortecerto_flutter/core/router/rotas.dart';
import 'package:cortecerto_flutter/core/session/session_controller.dart';
import 'package:cortecerto_flutter/core/session/usuario.dart';
import 'package:cortecerto_flutter/features/admin/domain/faturamento.dart';
import 'package:cortecerto_flutter/features/admin/presentation/faturamento_page.dart';
import 'package:cortecerto_flutter/features/servicos/domain/servico.dart';
import 'package:cortecerto_flutter/features/servicos/presentation/servicos_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    registerFallbackValue(DateTime(2030));
  });

  group('redirecionarPorSessao em /admin/faturamento', () {
    Future<SessionController> sessao(String? role) async {
      final s = SessionController(FakeTokenStorage());
      if (role != null) await s.iniciar('t', Usuario(id: 1, nome: 'n', role: role));
      return s;
    }

    test('caminho e nome da rota', () {
      expect(Rotas.adminFaturamento, '/admin/faturamento');
      expect(Rotas.nomeAdminFaturamento, 'admin-faturamento');
      expect(Rotas.isAdmin(Rotas.adminFaturamento), isTrue);
    });

    test('ADMIN acessa; CLIENTE vai para /servicos; sem sessão vai para /login', () async {
      expect(redirecionarPorSessao(await sessao('ADMIN'), Rotas.adminFaturamento), isNull);
      expect(redirecionarPorSessao(await sessao('CLIENTE'), Rotas.adminFaturamento), Rotas.servicos);
      expect(redirecionarPorSessao(await sessao(null), Rotas.adminFaturamento), Rotas.login);
    });
  });

  group('App inteiro (router real)', () {
    late MockAdminAgendamentoApi adminApi;
    late MockServicosApi servicosApi;

    setUp(() {
      adminApi = MockAdminAgendamentoApi();
      servicosApi = MockServicosApi();
      when(() => adminApi.listar(any())).thenAnswer((_) async => []);
      when(() => adminApi.faturamento(any(), any())).thenAnswer((i) async => Faturamento(
            inicio: i.positionalArguments[0] as DateTime,
            fim: i.positionalArguments[1] as DateTime,
            recebidoCentavos: 4000,
            previstoCentavos: 0,
            quantidadeRealizados: 1,
            quantidadePrevistos: 0,
          ));
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
          agendamentoApi: MockAgendamentoApi(),
          adminAgendamentoApi: adminApi,
          clientesApi: MockClientesApi(),
        ),
        localInicial: local,
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('ADMIN abre /admin/faturamento direto: Dia = hoje', (tester) async {
      await abrir(tester, criarJwt(role: 'ADMIN'), Rotas.adminFaturamento);
      expect(find.byType(FaturamentoPage), findsOneWidget);
      final agora = DateTime.now();
      final hoje = DateTime(agora.year, agora.month, agora.day);
      verify(() => adminApi.faturamento(hoje, hoje)).called(1);
      expect(find.text(r'R$ 40,00'), findsOneWidget);
    });

    testWidgets('ADMIN: Painel → card Faturamento → voltar ao Painel', (tester) async {
      await abrir(tester, criarJwt(role: 'ADMIN', name: 'Chefe'), Rotas.admin);
      await tester.tap(find.byKey(const Key('card-faturamento')));
      await tester.pumpAndSettle();
      expect(find.byType(FaturamentoPage), findsOneWidget);
      verify(() => adminApi.faturamento(any(), any())).called(1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Painel Admin'), findsOneWidget);
    });

    testWidgets('CLIENTE em /admin/faturamento → /servicos, sem chamar a API de faturamento', (tester) async {
      await abrir(tester, criarJwt(), Rotas.adminFaturamento);
      expect(find.byType(FaturamentoPage), findsNothing);
      expect(find.byType(ServicosPage), findsOneWidget);
      verifyNever(() => adminApi.faturamento(any(), any()));
    });
  });
}
