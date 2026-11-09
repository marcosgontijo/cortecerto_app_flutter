// FASE 3 (developer): widget tests do Painel Admin, Agenda Admin (com o formulário real),
// Meus Agendamentos e das pendências da FASE 2 (PopScope do Confirmado, sair durante o carregamento).
import 'dart:async';

import 'package:cortecerto_flutter/core/errors/api_exception.dart';
import 'package:cortecerto_flutter/core/router/rotas.dart';
import 'package:cortecerto_flutter/core/session/session_controller.dart';
import 'package:cortecerto_flutter/core/session/usuario.dart';
import 'package:cortecerto_flutter/core/theme/app_theme.dart';
import 'package:cortecerto_flutter/features/admin/data/admin_agendamento_api.dart';
import 'package:cortecerto_flutter/features/admin/data/clientes_api.dart';
import 'package:cortecerto_flutter/features/admin/domain/agendamento_admin.dart';
import 'package:cortecerto_flutter/features/admin/presentation/admin_page.dart';
import 'package:cortecerto_flutter/features/admin/presentation/agenda_admin_controller.dart';
import 'package:cortecerto_flutter/features/admin/presentation/agenda_admin_page.dart';
import 'package:cortecerto_flutter/features/admin/presentation/agendamento_form_controller.dart';
import 'package:cortecerto_flutter/features/admin/presentation/agendamento_form_page.dart';
import 'package:cortecerto_flutter/features/agendamento/data/agendamento_api.dart';
import 'package:cortecerto_flutter/features/agendamento/domain/agendamento_confirmado.dart';
import 'package:cortecerto_flutter/features/agendamento/domain/status_agendamento.dart';
import 'package:cortecerto_flutter/features/agendamento/presentation/agendamento_confirmado_page.dart';
import 'package:cortecerto_flutter/features/agendamento/presentation/agendamento_controller.dart';
import 'package:cortecerto_flutter/features/agendamento/presentation/agendamento_page.dart';
import 'package:cortecerto_flutter/features/meus_agendamentos/domain/meu_agendamento.dart';
import 'package:cortecerto_flutter/features/meus_agendamentos/presentation/meus_agendamentos_controller.dart';
import 'package:cortecerto_flutter/features/meus_agendamentos/presentation/meus_agendamentos_page.dart';
import 'package:cortecerto_flutter/features/servicos/data/servicos_api.dart';
import 'package:cortecerto_flutter/features/servicos/domain/servico.dart';
import 'package:cortecerto_flutter/features/servicos/presentation/servicos_controller.dart';
import 'package:cortecerto_flutter/features/servicos/presentation/servicos_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../helpers/fakes.dart';
import '../helpers/widget_helpers.dart';

const _servico = Servico(id: 1, tipoServico: 'Corte Simples', precoServico: '35.00');
const _barba = Servico(id: 2, tipoServico: 'Barba', precoServico: '25.00');
final _dia = DateTime(2030, 1, 15);
const _conflito = ApiException(tipo: ApiErrorTipo.conflito, statusCode: 409, mensagem: 'Horário indisponível');

AgendamentoAdmin ag(int id, String horario, StatusAgendamento status, {String nome = 'Ana Souza'}) =>
    AgendamentoAdmin(
      id: id,
      data: _dia,
      horario: horario,
      status: status,
      servicoId: 1,
      servico: 'Corte Simples',
      clienteId: 50 + id,
      nomeCliente: nome,
      telefoneCliente: id.isEven ? null : '11999990000',
    );

Future<void> tocar(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  late SessionController session;

  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    registerFallbackValue(_servico);
    registerFallbackValue(DateTime(2030));
    registerFallbackValue(StatusAgendamento.pendente);
  });

  setUp(() async {
    session = SessionController(FakeTokenStorage());
    await session.iniciar('t', const Usuario(id: 9, nome: 'Chefe', role: 'ADMIN'));
  });

  testWidgets('Painel Admin: saudação, card Agenda leva a /admin/agenda e sair', (tester) async {
    await tester.pumpWidget(comRouter(const AdminPage(), providers: [
      ChangeNotifierProvider<SessionController>.value(value: session),
    ]));
    expect(find.text('Painel Admin'), findsOneWidget);
    expect(find.text('Olá, Chefe!'), findsOneWidget);
    expect(find.text('Clientes'), findsNothing);
    await tester.tap(find.byKey(const Key('card-agenda')));
    await tester.pumpAndSettle();
    expect(find.text('TELA agenda'), findsOneWidget);
  });

  group('Agenda Admin', () {
    late MockAdminAgendamentoApi api;
    late MockClientesApi clientesApi;
    late MockAgendamentoApi agendamentoApi;
    late MockServicosApi servicosApi;
    late List<AgendamentoAdmin> doDia;

    setUp(() {
      api = MockAdminAgendamentoApi();
      clientesApi = MockClientesApi();
      agendamentoApi = MockAgendamentoApi();
      servicosApi = MockServicosApi();
      doDia = [
        ag(1, '09:00', StatusAgendamento.pendente, nome: 'Ana Souza'),
        ag(2, '10:00', StatusAgendamento.confirmado, nome: 'Bruno Lima'),
        ag(3, '10:00', StatusAgendamento.cancelado, nome: 'Carlos Dias'),
        ag(4, '11:00', StatusAgendamento.realizado, nome: 'Dani Rocha'),
      ];
      when(() => api.listar(any())).thenAnswer((_) async => doDia);
      when(() => servicosApi.listar()).thenAnswer((_) async => const [_servico, _barba]);
      when(() => agendamentoApi.disponibilidades(any())).thenAnswer((_) async => ['12:00', '12:30']);
    });

    Widget montar() {
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => ChangeNotifierProvider(
            create: (_) => AgendaAdminController(api, relogio: () => DateTime(2030, 1, 15, 8)),
            child: const AgendaAdminPage(),
          ),
        ),
        GoRoute(
          path: Rotas.adminAgendamentoForm,
          name: Rotas.nomeAdminAgendamentoForm,
          builder: (ctx, s) => ChangeNotifierProvider(
            create: (c) => AgendamentoFormController(
              adminApi: c.read<AdminAgendamentoApi>(),
              clientesApi: c.read<ClientesApi>(),
              agendamentoApi: c.read<AgendamentoApi>(),
              servicosApi: c.read<ServicosApi>(),
              args: s.extra! as AgendamentoFormArgs,
            ),
            child: const AgendamentoFormPage(),
          ),
        ),
      ]);
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session),
          Provider<AdminAgendamentoApi>.value(value: api),
          Provider<ClientesApi>.value(value: clientesApi),
          Provider<AgendamentoApi>.value(value: agendamentoApi),
          Provider<ServicosApi>.value(value: servicosApi),
        ],
        child: MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
      );
    }

    Future<void> abrir(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();
    }

    Future<void> abrirDetalhes(WidgetTester tester, String horario) async {
      await tocar(tester, find.byKey(Key('agenda-horario-$horario')));
      expect(find.byKey(const Key('detalhes-agendamento')), findsOneWidget);
    }

    testWidgets('grade 08:00–19:30 com ocupado/disponível, ativo sobre cancelado e contadores',
        (tester) async {
      await abrir(tester);
      expect(find.text('Agenda - Hoje'), findsOneWidget);
      verify(() => api.listar(_dia)).called(1);
      final slot10 = find.byKey(const Key('agenda-horario-10:00'));
      expect(find.descendant(of: slot10, matching: find.text('Bruno Lima')), findsOneWidget);
      expect(find.text('Carlos Dias'), findsNothing); // cancelado não aparece sobre o ativo
      expect(find.descendant(of: find.byKey(const Key('agenda-horario-09:00')), matching: find.text('Pendente')),
          findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('agenda-horario-08:00')), matching: find.text('Disponível')),
          findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const Key('agenda-horario-19:30')), 300,
          scrollable: find.descendant(of: find.byKey(const Key('agenda-refresh')), matching: find.byType(Scrollable)).first);
      expect(find.descendant(of: find.byKey(const Key('agenda-horario-19:30')), matching: find.text('Disponível')),
          findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, 5000));
      await tester.pumpAndSettle();
      String valor(String k) => tester.widget<Text>(find.byKey(Key('contador-$k-valor'))).data!;
      expect(valor('total'), '4');
      expect(valor('PENDENTE'), '1');
      expect(valor('CONFIRMADO'), '1');
      expect(valor('CANCELADO'), '1');
      expect(valor('REALIZADO'), '1');
    });

    testWidgets('filtro por status e busca por nome; Amanhã recarrega; pull-to-refresh', (tester) async {
      await abrir(tester);
      await tocar(tester, find.byKey(const Key('filtro-CANCELADO')));
      expect(find.text('Carlos Dias'), findsOneWidget);
      expect(find.text('Bruno Lima'), findsNothing);
      expect(find.text('Disponível'), findsNothing);
      await tocar(tester, find.byKey(const Key('filtro-todos')));
      await tester.enterText(find.byKey(const Key('campo-busca-agenda')), 'dani');
      await tester.pumpAndSettle();
      expect(find.text('Dani Rocha'), findsOneWidget);
      expect(find.text('Ana Souza'), findsNothing);
      await tester.enterText(find.byKey(const Key('campo-busca-agenda')), 'ninguém');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('agenda-vazia')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('campo-busca-agenda')), '');
      await tester.pumpAndSettle();

      await tocar(tester, find.byKey(const Key('periodo-amanha')));
      expect(find.text('Agenda - Amanhã'), findsOneWidget);
      verify(() => api.listar(DateTime(2030, 1, 16))).called(1);

      await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
      await tester.pumpAndSettle();
      clearInteractions(api);
      await tester.fling(find.byType(ListView).first, const Offset(0, 600), 1500);
      await tester.pumpAndSettle();
      verify(() => api.listar(DateTime(2030, 1, 16))).called(1);
    });

    testWidgets('criar a partir de um horário Disponível: busca cliente, serviço, horário e status',
        (tester) async {
      when(() => clientesApi.buscar('mar')).thenAnswer(
          (_) async => const [ClienteResumo(id: 77, nome: 'Marcos', cpf: '***.***.***-25', telefone: '11988887777')]);
      when(() => api.criar(
            clienteId: any(named: 'clienteId'),
            servicoId: any(named: 'servicoId'),
            data: any(named: 'data'),
            horario: any(named: 'horario'),
            status: any(named: 'status'),
          )).thenAnswer((_) async => ag(9, '12:00', StatusAgendamento.pendente));
      await abrir(tester);
      await tocar(tester, find.byKey(const Key('agenda-horario-12:00')));
      expect(find.text('Novo agendamento'), findsOneWidget);
      final chip = tester.widget<ChoiceChip>(find.byKey(const Key('form-horario-12:00')));
      expect(chip.selected, isTrue);
      await tester.enterText(find.byKey(const Key('campo-busca-cliente')), 'mar');
      await tocar(tester, find.byKey(const Key('botao-buscar-cliente')));
      await tocar(tester, find.byKey(const Key('form-cliente-77')));
      await tocar(tester, find.byKey(const Key('form-servico-2')));
      await tocar(tester, find.byKey(const Key('form-status-PENDENTE')));
      clearInteractions(api);
      await tocar(tester, find.byKey(const Key('form-botao-salvar')));
      verify(() => api.criar(
          clienteId: 77, servicoId: 2, data: _dia, horario: '12:00', status: StatusAgendamento.pendente)).called(1);
      expect(find.text('Agenda - Hoje'), findsOneWidget);
      expect(find.text('Agendamento criado.'), findsOneWidget);
      verify(() => api.listar(_dia)).called(1);
    });

    testWidgets('criar com 409 mostra "Horário indisponível" e recarrega os horários livres', (tester) async {
      when(() => clientesApi.buscar(any())).thenAnswer((_) async => const [ClienteResumo(id: 77, nome: 'Marcos')]);
      when(() => api.criar(
            clienteId: any(named: 'clienteId'),
            servicoId: any(named: 'servicoId'),
            data: any(named: 'data'),
            horario: any(named: 'horario'),
            status: any(named: 'status'),
          )).thenThrow(_conflito);
      await abrir(tester);
      await tocar(tester, find.byKey(const Key('botao-novo-agendamento')));
      await tester.enterText(find.byKey(const Key('campo-busca-cliente')), 'Marcos');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tocar(tester, find.byKey(const Key('form-cliente-77')));
      await tocar(tester, find.byKey(const Key('form-servico-1')));
      await tocar(tester, find.byKey(const Key('form-horario-12:30')));
      clearInteractions(agendamentoApi);
      await tocar(tester, find.byKey(const Key('form-botao-salvar')));
      expect(find.byKey(const Key('form-erro')), findsOneWidget);
      expect(find.text('Horário indisponível'), findsOneWidget);
      verify(() => agendamentoApi.disponibilidades(_dia)).called(1);
      expect(find.text('Novo agendamento'), findsOneWidget);
    });

    testWidgets('detalhes mostram os dados (telefone ausente tolerado) e Editar salva', (tester) async {
      when(() => api.atualizar(any(),
              servicoId: any(named: 'servicoId'),
              data: any(named: 'data'),
              horario: any(named: 'horario'),
              status: any(named: 'status')))
          .thenAnswer((_) async => ag(2, '12:30', StatusAgendamento.confirmado));
      await abrir(tester);
      await abrirDetalhes(tester, '10:00');
      expect(find.text('Bruno Lima'), findsWidgets);
      expect(find.textContaining('Não informado'), findsOneWidget);
      expect(find.textContaining('15/01/2030'), findsOneWidget);
      expect(find.byKey(const Key('acao-confirmar')), findsNothing); // já confirmado
      await tocar(tester, find.byKey(const Key('acao-editar')));
      expect(find.text('Editar agendamento'), findsOneWidget);
      expect(find.byKey(const Key('campo-busca-cliente')), findsNothing);
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('form-horario-10:00'))).selected, isTrue);
      await tocar(tester, find.byKey(const Key('form-horario-12:30')));
      await tocar(tester, find.byKey(const Key('form-status-PENDENTE')));
      await tocar(tester, find.byKey(const Key('form-botao-salvar')));
      verify(() => api.atualizar(2,
          servicoId: 1, data: _dia, horario: '12:30', status: StatusAgendamento.pendente)).called(1);
      expect(find.text('Agendamento atualizado.'), findsOneWidget);
    });

    testWidgets('Confirmar e Marcar como realizado recarregam a agenda', (tester) async {
      when(() => api.atualizar(any(), status: any(named: 'status')))
          .thenAnswer((_) async => ag(1, '09:00', StatusAgendamento.confirmado));
      await abrir(tester);
      clearInteractions(api);
      await abrirDetalhes(tester, '09:00');
      expect(find.textContaining('11999990000'), findsOneWidget);
      await tocar(tester, find.byKey(const Key('acao-confirmar')));
      verify(() => api.atualizar(1, status: StatusAgendamento.confirmado)).called(1);
      expect(find.text('Agendamento confirmado.'), findsOneWidget);
      verify(() => api.listar(_dia)).called(1);

      await abrirDetalhes(tester, '09:00');
      await tocar(tester, find.byKey(const Key('acao-realizar')));
      verify(() => api.atualizar(1, status: StatusAgendamento.realizado)).called(1);
      expect(find.text('Agendamento marcado como realizado.'), findsOneWidget);
    });

    testWidgets('Cancelar e Excluir pedem confirmação; "Voltar" não chama a API', (tester) async {
      when(() => api.cancelar(any())).thenAnswer((_) async {});
      when(() => api.excluir(any())).thenAnswer((_) async {});
      await abrir(tester);

      await abrirDetalhes(tester, '09:00');
      await tocar(tester, find.byKey(const Key('acao-cancelar')));
      expect(find.byType(AlertDialog), findsOneWidget);
      await tocar(tester, find.byKey(const Key('dialogo-nao')));
      verifyNever(() => api.cancelar(any()));

      await abrirDetalhes(tester, '09:00');
      await tocar(tester, find.byKey(const Key('acao-cancelar')));
      await tocar(tester, find.byKey(const Key('dialogo-sim')));
      verify(() => api.cancelar(1)).called(1);
      expect(find.text('Agendamento cancelado.'), findsOneWidget);

      await abrirDetalhes(tester, '11:00');
      await tocar(tester, find.byKey(const Key('acao-excluir')));
      expect(find.byType(AlertDialog), findsOneWidget);
      await tocar(tester, find.byKey(const Key('dialogo-sim')));
      verify(() => api.excluir(4)).called(1);
      expect(find.text('Agendamento excluído.'), findsOneWidget);
    });

    testWidgets('erro 409 numa ação mostra a mensagem do backend e recarrega', (tester) async {
      when(() => api.atualizar(any(), status: any(named: 'status'))).thenThrow(_conflito);
      await abrir(tester);
      clearInteractions(api);
      await abrirDetalhes(tester, '09:00');
      await tocar(tester, find.byKey(const Key('acao-confirmar')));
      expect(find.byKey(const Key('snack-erro')), findsOneWidget);
      expect(find.text('Horário indisponível'), findsOneWidget);
      verify(() => api.listar(_dia)).called(1);
    });

    testWidgets('erro ao carregar mostra "Tentar novamente"', (tester) async {
      when(() => api.listar(any())).thenThrow(
          const ApiException(tipo: ApiErrorTipo.semConexao, mensagem: ApiErrorMapper.msgSemConexao));
      await abrir(tester);
      expect(find.byKey(const Key('agenda-erro')), findsOneWidget);
      expect(find.text(ApiErrorMapper.msgSemConexao), findsOneWidget);
    });
  });

  group('Meus Agendamentos', () {
    late MockAgendamentoApi api;
    final agora = DateTime(2030, 1, 15, 10);
    var lista = <MeuAgendamento>[];

    MeuAgendamento m(int id, DateTime data, String h, StatusAgendamento s, [String servico = 'Corte']) =>
        MeuAgendamento(id: id, data: data, horario: h, status: s, servico: servico);

    setUp(() async {
      await session.iniciar('t', const Usuario(id: 3, nome: 'Maria', role: 'CLIENTE'));
      api = MockAgendamentoApi();
      lista = [
        m(1, DateTime(2030, 1, 20), '09:00', StatusAgendamento.confirmado, 'Barba'),
        m(2, DateTime(2030, 1, 10), '09:00', StatusAgendamento.realizado, 'Sobrancelha'),
        m(3, DateTime(2030, 1, 18), '14:00', StatusAgendamento.cancelado, 'Corte Completo'),
      ];
      when(() => api.meus()).thenAnswer((_) async => lista);
    });

    Widget montar() => comRouter(const MeusAgendamentosPage(), providers: [
          ChangeNotifierProvider<SessionController>.value(value: session),
          ChangeNotifierProvider(create: (_) => MeusAgendamentosController(api, relogio: () => agora)),
        ]);

    testWidgets('carrega ao abrir; Próximos e Histórico com status', (tester) async {
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();
      verify(() => api.meus()).called(1);
      expect(find.text('Próximos (1)'), findsOneWidget);
      expect(find.text('Histórico (2)'), findsOneWidget);
      expect(find.text('Barba'), findsOneWidget);
      expect(find.text('Confirmado'), findsOneWidget);
      await tester.tap(find.byKey(const Key('aba-historico')));
      await tester.pumpAndSettle();
      expect(find.text('Sobrancelha'), findsOneWidget);
      expect(find.text('Realizado'), findsOneWidget);
      expect(find.text('Cancelado'), findsOneWidget);
      expect(find.byKey(const Key('botao-cancelar-2')), findsNothing);
      expect(find.byKey(const Key('botao-cancelar-3')), findsNothing);
    });

    testWidgets('pull-to-refresh e voltar ao primeiro plano buscam de novo no servidor', (tester) async {
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();
      lista = [m(1, DateTime(2030, 1, 20), '11:30', StatusAgendamento.pendente, 'Barba')];
      await tester.fling(find.byKey(const Key('lista-proximos')), const Offset(0, 600), 1500);
      await tester.pumpAndSettle();
      expect(find.textContaining('11:30'), findsOneWidget);
      expect(find.text('Pendente'), findsOneWidget);

      lista = [];
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pumpAndSettle();
      verify(() => api.meus()).called(3);
      expect(find.byKey(const Key('meus-vazio')), findsOneWidget);
    });

    testWidgets('cancelar o próprio futuro pede confirmação e atualiza a lista', (tester) async {
      when(() => api.cancelar(1)).thenAnswer((_) async {
        lista = [m(1, DateTime(2030, 1, 20), '09:00', StatusAgendamento.cancelado, 'Barba')];
      });
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('botao-cancelar-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dialogo-nao')));
      await tester.pumpAndSettle();
      verifyNever(() => api.cancelar(any()));

      await tester.tap(find.byKey(const Key('botao-cancelar-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dialogo-sim')));
      await tester.pumpAndSettle();
      verify(() => api.cancelar(1)).called(1);
      expect(find.text('Agendamento cancelado.'), findsOneWidget);
      expect(find.text('Próximos (0)'), findsOneWidget);
      expect(find.text('Histórico (1)'), findsOneWidget);
    });

    testWidgets('erro do backend ao cancelar aparece', (tester) async {
      when(() => api.cancelar(1)).thenThrow(const ApiException(
          tipo: ApiErrorTipo.dadosInvalidos, mensagem: 'Não é possível cancelar um agendamento passado'));
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('botao-cancelar-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dialogo-sim')));
      await tester.pumpAndSettle();
      expect(find.text('Não é possível cancelar um agendamento passado'), findsOneWidget);
    });
  });

  group('Acesso a Meus Agendamentos', () {
    setUp(() async => session.iniciar('t', const Usuario(id: 3, nome: 'Maria', role: 'CLIENTE')));

    testWidgets('pela tela de Serviços', (tester) async {
      final api = MockServicosApi();
      when(() => api.listar()).thenAnswer((_) async => const [_servico]);
      await tester.pumpWidget(comRouter(const ServicosPage(), providers: [
        ChangeNotifierProvider<SessionController>.value(value: session),
        ChangeNotifierProvider(create: (_) => ServicosController(api)),
      ]));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('botao-meus-agendamentos')));
      await tester.pumpAndSettle();
      expect(find.text('TELA meus'), findsOneWidget);
    });

    Widget confirmado() => comRouter(
          AgendamentoConfirmadoPage(
            resumo: AgendamentoConfirmado(servico: 'Barba', data: DateTime(2030, 1, 5), horario: '09:00'),
          ),
          providers: [ChangeNotifierProvider<SessionController>.value(value: session)],
        );

    testWidgets('pela tela Confirmado', (tester) async {
      await tester.pumpWidget(confirmado());
      await tester.tap(find.byKey(const Key('botao-meus-agendamentos')));
      await tester.pumpAndSettle();
      expect(find.text('TELA meus'), findsOneWidget);
    });

    testWidgets('Confirmado: Voltar do Android leva a /servicos (PopScope) sem fechar o app',
        (tester) async {
      await tester.pumpWidget(confirmado());
      final popou = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(popou, isTrue); // o app tratou o Voltar (não fechou)
      expect(find.text('TELA servicos'), findsOneWidget);
    });
  });

  group('Pendências da FASE 2', () {
    setUp(() async => session.iniciar('t', const Usuario(id: 3, nome: 'Maria', role: 'CLIENTE')));

    testWidgets('sair da tela de Serviços durante o carregamento não lança exceção', (tester) async {
      final api = MockServicosApi();
      final c = Completer<List<Servico>>();
      when(() => api.listar()).thenAnswer((_) => c.future);
      await tester.pumpWidget(comRouter(const ServicosPage(), providers: [
        ChangeNotifierProvider<SessionController>.value(value: session),
        ChangeNotifierProvider(create: (_) => ServicosController(api)),
      ]));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // troca a árvore inteira: o provider descarta o controller
      await tester.pumpWidget(const SizedBox());
      c.complete(const [_servico]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('calendário com data fixa: ontem desabilitado não chama a API', (tester) async {
      final api = MockAgendamentoApi();
      await tester.pumpWidget(comRouter(AgendamentoPage(servico: _servico, hoje: DateTime(2030, 1, 15)),
          providers: [
            ChangeNotifierProvider<SessionController>.value(value: session),
            ChangeNotifierProvider(create: (_) => AgendamentoController(api)),
          ]));
      await tester.tap(find.text('14'));
      await tester.pumpAndSettle();
      verifyNever(() => api.disponibilidades(any()));
      expect(find.byKey(const Key('horarios-escolha-dia')), findsOneWidget);
    });

    testWidgets('"hoje" do calendário é recalculado (virada do dia)', (tester) async {
      final api = MockAgendamentoApi();
      when(() => api.disponibilidades(any())).thenAnswer((_) async => ['09:00']);
      var agora = DateTime(2030, 1, 15, 23, 59);
      await tester.pumpWidget(comRouter(AgendamentoPage(servico: _servico, relogio: () => agora),
          providers: [
            ChangeNotifierProvider<SessionController>.value(value: session),
            ChangeNotifierProvider(create: (_) => AgendamentoController(api)),
          ]));
      agora = DateTime(2030, 1, 16, 0, 1); // passou da meia-noite com a tela aberta
      for (final s in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('15').first);
      await tester.pumpAndSettle();
      verifyNever(() => api.disponibilidades(any()));
      await tester.tap(find.text('16').first);
      await tester.pumpAndSettle();
      verify(() => api.disponibilidades(DateTime(2030, 1, 16))).called(1);
    });
  });
}
