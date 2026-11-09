// FASE 3, volta 2 (tester): bordas das correções da volta 2 — limites do calendário (data > hoje+365,
// initialDate fora do intervalo, virada da meia-noite), criação sem data/horário passado (grade com
// "Horário encerrado"), status desconhecido e corrida nos cancelamentos.
import 'dart:async';

import 'package:cortecerto_flutter/core/errors/api_exception.dart';
import 'package:cortecerto_flutter/core/formatters/formatters.dart';
import 'package:cortecerto_flutter/core/router/rotas.dart';
import 'package:cortecerto_flutter/core/session/session_controller.dart';
import 'package:cortecerto_flutter/core/session/usuario.dart';
import 'package:cortecerto_flutter/core/theme/app_theme.dart';
import 'package:cortecerto_flutter/features/admin/data/admin_agendamento_api.dart';
import 'package:cortecerto_flutter/features/admin/data/clientes_api.dart';
import 'package:cortecerto_flutter/features/admin/domain/agendamento_admin.dart';
import 'package:cortecerto_flutter/features/admin/presentation/agenda_admin_controller.dart';
import 'package:cortecerto_flutter/features/admin/presentation/agenda_admin_page.dart';
import 'package:cortecerto_flutter/features/admin/presentation/agendamento_form_controller.dart';
import 'package:cortecerto_flutter/features/admin/presentation/agendamento_form_page.dart';
import 'package:cortecerto_flutter/features/agendamento/data/agendamento_api.dart';
import 'package:cortecerto_flutter/features/agendamento/domain/status_agendamento.dart';
import 'package:cortecerto_flutter/features/meus_agendamentos/domain/meu_agendamento.dart';
import 'package:cortecerto_flutter/features/meus_agendamentos/presentation/meus_agendamentos_controller.dart';
import 'package:cortecerto_flutter/features/meus_agendamentos/presentation/meus_agendamentos_page.dart';
import 'package:cortecerto_flutter/features/servicos/data/servicos_api.dart';
import 'package:cortecerto_flutter/features/servicos/domain/servico.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../helpers/fakes.dart';
import '../helpers/widget_helpers.dart';

const _servico = Servico(id: 1, tipoServico: 'Corte Simples', precoServico: '35.00');
final _hoje = DateTime(2030, 1, 15);

/// "Agora" mutável dos testes (cada teste ajusta).
DateTime _agora = DateTime(2030, 1, 15, 10, 10);
DateTime _relogio() => _agora;

AgendamentoAdmin ag(int id, String horario, StatusAgendamento status, {DateTime? data, String? nome}) =>
    AgendamentoAdmin(
      id: id,
      data: data ?? _hoje,
      horario: horario,
      status: status,
      servicoId: 1,
      servico: 'Corte Simples',
      clienteId: 100 + id,
      nomeCliente: nome ?? 'Cliente $id',
      telefoneCliente: '11988887777',
    );

MeuAgendamento meu(int id, DateTime data, String horario, StatusAgendamento s) =>
    MeuAgendamento(id: id, data: data, horario: horario, status: s, servico: 'Serviço $id');

Future<void> tocar(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f, warnIfMissed: false);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    registerFallbackValue(DateTime(2030));
    registerFallbackValue(StatusAgendamento.pendente);
  });

  late MockAdminAgendamentoApi admin;
  late MockClientesApi clientes;
  late MockAgendamentoApi agenda;
  late MockServicosApi servicos;

  setUp(() {
    _agora = DateTime(2030, 1, 15, 10, 10);
    admin = MockAdminAgendamentoApi();
    clientes = MockClientesApi();
    agenda = MockAgendamentoApi();
    servicos = MockServicosApi();
    when(() => servicos.listar()).thenAnswer((_) async => const [_servico]);
    when(() => agenda.disponibilidades(any()))
        .thenAnswer((_) async => ['08:00', '09:30', '10:00', '10:30', '19:30']);
    when(() => admin.listar(any())).thenAnswer((_) async => const []);
  });

  AgendamentoFormController form(AgendamentoFormArgs args) => AgendamentoFormController(
        adminApi: admin,
        clientesApi: clientes,
        agendamentoApi: agenda,
        servicosApi: servicos,
        args: args,
        relogio: _relogio,
      );

  void invariante(AgendamentoFormController c, String caso) {
    final p = c.primeiroDiaCalendario, i = c.diaInicialCalendario, u = c.ultimoDiaCalendario;
    expect(!p.isAfter(i) && !i.isAfter(u), isTrue, reason: '$caso: first=$p initial=$i last=$u');
    expect(!u.isBefore(c.hoje.add(const Duration(days: 365))), isTrue, reason: '$caso: lastDate < hoje+365');
    for (final d in [p, i, u]) {
      expect(d, DateTime(d.year, d.month, d.day), reason: '$caso: data com hora');
    }
  }

  // ===================================================================== calendário do formulário
  group('Formulário admin: limites do calendário (bordas)', () {
    test('edição exatamente em hoje+365 e em hoje+366', () {
      final d365 = _hoje.add(const Duration(days: 365));
      final d366 = _hoje.add(const Duration(days: 366));
      final a = form(AgendamentoFormArgs.editar(ag(1, '10:00', StatusAgendamento.confirmado, data: d365)));
      expect(a.ultimoDiaCalendario, d365);
      expect(a.diaInicialCalendario, d365);
      final b = form(AgendamentoFormArgs.editar(ag(1, '10:00', StatusAgendamento.confirmado, data: d366)));
      expect(b.ultimoDiaCalendario, d366);
      expect(b.diaInicialCalendario, d366);
    });

    test('edição distante: escolher outra data não encolhe o calendário (a original continua alcançável)', () async {
      final longe = DateTime(2033, 6, 1);
      final c = form(AgendamentoFormArgs.editar(ag(1, '10:00', StatusAgendamento.confirmado, data: longe)));
      await c.selecionarData(DateTime(2030, 2, 1));
      expect(c.ultimoDiaCalendario, longe);
      expect(c.diaInicialCalendario, DateTime(2030, 2, 1));
      expect(c.primeiroDiaCalendario, _hoje);
    });

    test('edição de agendamento a mais de 1 ano no passado: firstDate = data dele', () {
      final antigo = DateTime(2028, 6, 1);
      final c = form(AgendamentoFormArgs.editar(ag(1, '10:00', StatusAgendamento.realizado, data: antigo)));
      expect(c.primeiroDiaCalendario, antigo);
      expect(c.diaInicialCalendario, antigo);
      invariante(c, 'passado distante');
    });

    test('virada da meia-noite com o formulário aberto: initialDate é puxado para dentro do intervalo', () async {
      _agora = DateTime(2030, 1, 15, 23, 50);
      final c = form(AgendamentoFormArgs.criar(data: _hoje));
      expect(c.data, _hoje);
      _agora = DateTime(2030, 1, 16, 0, 10);
      expect(c.primeiroDiaCalendario, DateTime(2030, 1, 16));
      expect(c.diaInicialCalendario, DateTime(2030, 1, 16));
      invariante(c, 'meia-noite (criação)');
      // e na virada os horários do dia que ficou para trás somem (nada no passado)
      await c.carregarHorarios();
      expect(c.horarios, isEmpty);
      expect(c.podeSalvar, isFalse);
    });

    test('invariante first <= initial <= last em vários cenários (criação e edição, com hora no relógio)', () async {
      final agoras = [
        DateTime(2030, 1, 15, 0, 0),
        DateTime(2030, 1, 15, 23, 59, 59),
        DateTime(2030, 12, 31, 12),
        DateTime(2032, 2, 29, 9),
      ];
      final datas = [
        DateTime(2020, 1, 1),
        DateTime(2030, 1, 14),
        DateTime(2030, 1, 15, 18, 30),
        DateTime(2031, 1, 15),
        DateTime(2031, 1, 16),
        DateTime(2040, 7, 7),
      ];
      for (final n in agoras) {
        for (final d in datas) {
          _agora = n;
          invariante(form(AgendamentoFormArgs.criar(data: d, horario: '10:00')), 'criar agora=$n data=$d');
          final e = form(AgendamentoFormArgs.editar(ag(1, '10:00', StatusAgendamento.confirmado, data: d)));
          invariante(e, 'editar agora=$n data=$d');
          for (final outra in datas) {
            await e.selecionarData(outra);
            invariante(e, 'editar agora=$n data=$d escolhida=$outra');
          }
        }
      }
    });

    test('criação: firstDate nunca é antes de hoje, mesmo vindo de um dia passado ou com hora', () {
      for (final d in [DateTime(2029, 1, 1), DateTime(2030, 1, 14, 23, 59), DateTime(2030, 1, 15, 0, 1)]) {
        final c = form(AgendamentoFormArgs.criar(data: d));
        expect(c.primeiroDiaCalendario, _hoje, reason: '$d');
        expect(c.data.isBefore(_hoje), isFalse, reason: '$d');
      }
    });
  });

  // ===================================================================== criação sem passado
  group('Criação sem data/horário passado', () {
    test('borda do horário: exatamente agora ainda vale (isBefore estrito, igual ao backend); 1 ms depois não', () async {
      _agora = DateTime(2030, 1, 15, 10, 0);
      final c = form(AgendamentoFormArgs.criar(data: _hoje, horario: '10:00'));
      expect(c.horario, '10:00');
      await c.iniciar();
      expect(c.horarios, ['10:00', '10:30', '19:30']);
      _agora = DateTime(2030, 1, 15, 10, 0, 0, 1);
      final d = form(AgendamentoFormArgs.criar(data: _hoje, horario: '10:00'));
      expect(d.horario, isNull);
      await d.iniciar();
      expect(d.horarios, ['10:30', '19:30']);
      final api = MockAdminAgendamentoApi();
      when(() => api.listar(any())).thenAnswer((_) async => const []);
      _agora = DateTime(2030, 1, 15, 10, 0);
      final g = AgendaAdminController(api, relogio: _relogio);
      expect(g.horarioPassou('10:00'), isFalse);
      _agora = DateTime(2030, 1, 15, 10, 0, 0, 1);
      expect(g.horarioPassou('10:00'), isTrue);
    });

    test('trocar para amanhã mostra todos; voltar para hoje filtra de novo; hoje depois das 19:30 fica vazio', () async {
      final c = form(AgendamentoFormArgs.criar(data: _hoje));
      await c.iniciar();
      expect(c.horarios, ['10:30', '19:30']);
      await c.selecionarData(DateTime(2030, 1, 16));
      expect(c.horarios, ['08:00', '09:30', '10:00', '10:30', '19:30']);
      await c.selecionarData(_hoje);
      expect(c.horarios, ['10:30', '19:30']);
      _agora = DateTime(2030, 1, 15, 19, 31);
      await c.carregarHorarios();
      expect(c.horarios, isEmpty);
      expect(c.horario, isNull);
    });

    test('409 depois de o horário passar: recarrega e não reoferece o horário que passou', () async {
      when(() => admin.criar(
            clienteId: any(named: 'clienteId'),
            servicoId: any(named: 'servicoId'),
            data: any(named: 'data'),
            horario: any(named: 'horario'),
            status: any(named: 'status'),
          )).thenThrow(const ApiException(tipo: ApiErrorTipo.conflito, statusCode: 409, mensagem: 'Horário indisponível'));
      final c = form(AgendamentoFormArgs.criar(data: _hoje, horario: '10:30'));
      await c.iniciar();
      c.selecionarCliente(const ClienteResumo(id: 5, nome: 'Ana'));
      c.selecionarServico(1);
      _agora = DateTime(2030, 1, 15, 10, 40);
      expect(await c.salvar(), isFalse);
      expect(c.horarios, ['19:30']);
      expect(c.horario, isNull);
    });
  });

  // ===================================================================== widgets da Agenda / form
  group('Agenda Admin + formulário (widgets, relógio fixo)', () {
    late SessionController session;
    List<AgendamentoAdmin> doDia = const [];

    setUp(() async {
      session = SessionController(FakeTokenStorage());
      await session.iniciar('t', const Usuario(id: 9, nome: 'Chefe', role: 'ADMIN'));
      doDia = const [];
      when(() => admin.listar(any())).thenAnswer((_) async => doDia);
    });

    Widget montar() {
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => ChangeNotifierProvider(
            create: (_) => AgendaAdminController(admin, relogio: _relogio),
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
              relogio: _relogio,
            ),
            child: const AgendamentoFormPage(),
          ),
        ),
      ]);
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session),
          Provider<AdminAgendamentoApi>.value(value: admin),
          Provider<ClientesApi>.value(value: clientes),
          Provider<AgendamentoApi>.value(value: agenda),
          Provider<ServicosApi>.value(value: servicos),
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

    AgendaAdminController ctrl(WidgetTester tester) =>
        tester.element(find.byType(AgendaAdminPage)).read<AgendaAdminController>();

    Finder em(String horario, Finder f) =>
        find.descendant(of: find.byKey(Key('agenda-horario-$horario')), matching: f);

    Future<void> verSlot(WidgetTester tester, String h) async {
      await tester.scrollUntilVisible(find.byKey(Key('agenda-horario-$h')), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
    }

    testWidgets('dia passado: todos os horários livres ficam "Horário encerrado"; o "+" abre o form em HOJE',
        (tester) async {
      await abrir(tester);
      unawaited(ctrl(tester).selecionarData(DateTime(2030, 1, 14)));
      await tester.pumpAndSettle();
      for (final h in ['08:00', '12:00', '19:30']) {
        await verSlot(tester, h);
        expect(em(h, find.text('Horário encerrado')), findsOneWidget, reason: h);
        expect(em(h, find.byKey(const Key('slot-adicionar'))), findsNothing, reason: h);
      }
      expect(find.text('Disponível'), findsNothing);
      await tocar(tester, find.byKey(const Key('agenda-horario-19:30')));
      expect(find.text('Novo agendamento'), findsNothing);
      await tocar(tester, find.byKey(const Key('botao-novo-agendamento')));
      expect(find.text('Novo agendamento'), findsOneWidget);
      expect(find.text(Formatters.data(_hoje)), findsOneWidget);
      verify(() => agenda.disponibilidades(_hoje)).called(1);
      verifyNever(() => agenda.disponibilidades(DateTime(2030, 1, 14)));
    });

    testWidgets('hoje às 23:59: nenhum horário livre; amanhã: todos "Disponível"', (tester) async {
      _agora = DateTime(2030, 1, 15, 23, 59);
      await abrir(tester);
      expect(find.text('Disponível'), findsNothing);
      await verSlot(tester, '19:30');
      expect(em('19:30', find.text('Horário encerrado')), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const Key('periodo-amanha')), -200,
          scrollable: find.byType(Scrollable).first);
      await tocar(tester, find.byKey(const Key('periodo-amanha')));
      expect(find.text('Horário encerrado'), findsNothing);
      expect(em('08:00', find.text('Disponível')), findsOneWidget);
      await verSlot(tester, '19:30');
      expect(em('19:30', find.text('Disponível')), findsOneWidget);
    });

    testWidgets('horário passado só com cancelado: "Horário encerrado" com a nota, e tocar não abre o form',
        (tester) async {
      doDia = [ag(3, '09:00', StatusAgendamento.cancelado)];
      await abrir(tester);
      expect(em('09:00', find.text('Horário encerrado')), findsOneWidget);
      expect(em('09:00', find.text('1 cancelado neste horário')), findsOneWidget);
      await tocar(tester, find.byKey(const Key('agenda-horario-09:00')));
      expect(find.text('Novo agendamento'), findsNothing);
    });

    testWidgets('horário passado OCUPADO continua abrindo os detalhes (marcar realizado depois do horário)',
        (tester) async {
      doDia = [ag(1, '09:00', StatusAgendamento.confirmado, nome: 'Ana')];
      await abrir(tester);
      await tocar(tester, find.byKey(const Key('agenda-horario-09:00')));
      expect(find.byKey(const Key('detalhes-agendamento')), findsOneWidget);
      expect(find.byKey(const Key('acao-realizar')), findsOneWidget);
    });

    testWidgets('fluxo criar pelo "+" hoje às 10:10: só oferece horários futuros e envia data de hoje',
        (tester) async {
      when(() => clientes.buscar('ana')).thenAnswer((_) async => const [ClienteResumo(id: 5, nome: 'Ana')]);
      when(() => admin.criar(
            clienteId: any(named: 'clienteId'),
            servicoId: any(named: 'servicoId'),
            data: any(named: 'data'),
            horario: any(named: 'horario'),
            status: any(named: 'status'),
          )).thenAnswer((_) async => ag(9, '10:30', StatusAgendamento.confirmado));
      await abrir(tester);
      await tocar(tester, find.byKey(const Key('botao-novo-agendamento')));
      for (final h in ['08:00', '09:30', '10:00']) {
        expect(find.byKey(Key('form-horario-$h')), findsNothing, reason: h);
      }
      expect(find.byKey(const Key('form-horario-10:30')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('campo-busca-cliente')), 'ana');
      await tocar(tester, find.byKey(const Key('botao-buscar-cliente')));
      await tocar(tester, find.byKey(const Key('form-cliente-5')));
      await tocar(tester, find.byKey(const Key('form-servico-1')));
      await tocar(tester, find.byKey(const Key('form-horario-10:30')));
      await tocar(tester, find.byKey(const Key('form-botao-salvar')));
      verify(() => admin.criar(
          clienteId: 5, servicoId: 1, data: _hoje, horario: '10:30', status: StatusAgendamento.confirmado)).called(1);
    });

    testWidgets('editar agendamento de mais de 1 ano atrás abre o calendário sem quebrar', (tester) async {
      final antigo = DateTime(2028, 3, 10);
      await abrir(tester);
      unawaited(GoRouter.of(tester.element(find.byType(AgendaAdminPage))).pushNamed<bool>(
          Rotas.nomeAdminAgendamentoForm,
          extra: AgendamentoFormArgs.editar(ag(7, '10:00', StatusAgendamento.realizado, data: antigo))));
      await tester.pumpAndSettle();
      await tocar(tester, find.byKey(const Key('form-botao-data')));
      expect(tester.takeException(), isNull);
      final d = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
      expect(d.firstDate, antigo);
      expect(d.initialDate, antigo);
      expect(d.lastDate, _hoje.add(const Duration(days: 365)));
    });

    testWidgets('editar agendamento exatamente em hoje+366 abre o calendário sem quebrar', (tester) async {
      final d366 = _hoje.add(const Duration(days: 366));
      await abrir(tester);
      unawaited(GoRouter.of(tester.element(find.byType(AgendaAdminPage))).pushNamed<bool>(
          Rotas.nomeAdminAgendamentoForm,
          extra: AgendamentoFormArgs.editar(ag(7, '10:00', StatusAgendamento.confirmado, data: d366))));
      await tester.pumpAndSettle();
      await tocar(tester, find.byKey(const Key('form-botao-data')));
      expect(tester.takeException(), isNull);
      final d = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
      expect(d.lastDate, d366);
      expect(d.initialDate, d366);
    });

    testWidgets('form de criação aberto na virada da meia-noite: o calendário abre (initialDate ajustado)',
        (tester) async {
      _agora = DateTime(2030, 1, 15, 23, 50);
      await abrir(tester);
      await tocar(tester, find.byKey(const Key('botao-novo-agendamento')));
      _agora = DateTime(2030, 1, 16, 0, 5);
      await tocar(tester, find.byKey(const Key('form-botao-data')));
      expect(tester.takeException(), isNull);
      final d = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
      expect(d.firstDate, DateTime(2030, 1, 16));
      expect(d.initialDate, DateTime(2030, 1, 16));
    });

    testWidgets('ACHADO: Agenda "Data" depois da meia-noite com o dia mais antigo escolhido não pode quebrar',
        (tester) async {
      // A Agenda usa firstDate = hoje-365 e initialDate = dia exibido. Se o admin estava no limite
      // (hoje-365) e o dia vira, o initialDate fica antes do firstDate.
      await abrir(tester);
      unawaited(ctrl(tester).selecionarData(_hoje.subtract(const Duration(days: 365))));
      await tester.pumpAndSettle();
      _agora = DateTime(2030, 1, 16, 8);
      await tester.tap(find.byKey(const Key('periodo-data')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    // ------------------------------------------------------------- status desconhecido
    testWidgets('status desconhecido: ocupa o horário, sem contador/filtro próprio e sem Confirmar/Realizado',
        (tester) async {
      doDia = [
        AgendamentoAdmin.fromJson(const {
          'id': 1, 'data': '2030-01-15', 'horario': '11:00', 'status': 'NO_SHOW', 'servicoId': 1,
          'servico': 'Corte Simples', 'clienteId': 7, 'nomeCliente': 'Zeca', 'telefoneCliente': '1199',
        }),
        ag(2, '11:00', StatusAgendamento.cancelado),
        ag(3, '12:00', StatusAgendamento.pendente),
      ];
      expect(doDia.first.status, StatusAgendamento.desconhecido);
      await abrir(tester);
      expect(em('11:00', find.text('Desconhecido')), findsOneWidget);
      expect(em('11:00', find.text('Zeca')), findsOneWidget);
      expect(em('11:00', find.text('Disponível')), findsNothing);
      expect(find.byKey(const Key('contador-DESCONHECIDO')), findsNothing);
      expect(find.byKey(const Key('filtro-DESCONHECIDO')), findsNothing);
      // filtro PENDENTE não traz o desconhecido
      await tocar(tester, find.byKey(const Key('filtro-PENDENTE')));
      expect(find.byKey(const Key('agendamento-3')), findsOneWidget);
      expect(find.byKey(const Key('agendamento-1')), findsNothing);
      await tocar(tester, find.byKey(const Key('filtro-todos')));
      await tocar(tester, find.byKey(const Key('agenda-horario-11:00')));
      expect(find.byKey(const Key('acao-confirmar')), findsNothing);
      expect(find.byKey(const Key('acao-realizar')), findsNothing);
      expect(find.byKey(const Key('acao-editar')), findsOneWidget);
      expect(find.byKey(const Key('acao-cancelar')), findsOneWidget);
      expect(find.byKey(const Key('acao-excluir')), findsOneWidget);
    });

    testWidgets('editar um desconhecido: nenhum status pré-selecionado; escolher CONFIRMADO envia CONFIRMADO',
        (tester) async {
      when(() => admin.atualizar(any(),
              servicoId: any(named: 'servicoId'),
              data: any(named: 'data'),
              horario: any(named: 'horario'),
              status: any(named: 'status')))
          .thenAnswer((_) async => ag(1, '11:00', StatusAgendamento.confirmado));
      doDia = [ag(1, '11:00', StatusAgendamento.desconhecido)];
      when(() => agenda.disponibilidades(any())).thenAnswer((_) async => ['12:00']);
      await abrir(tester);
      await tocar(tester, find.byKey(const Key('agenda-horario-11:00')));
      await tocar(tester, find.byKey(const Key('acao-editar')));
      expect(find.byKey(const Key('form-status-DESCONHECIDO')), findsNothing);
      for (final s in StatusAgendamento.conhecidos) {
        expect(tester.widget<ChoiceChip>(find.byKey(Key('form-status-${s.api}'))).selected, isFalse, reason: s.api);
      }
      await tocar(tester, find.byKey(const Key('form-status-CONFIRMADO')));
      await tocar(tester, find.byKey(const Key('form-botao-salvar')));
      verify(() => admin.atualizar(1,
          servicoId: 1, data: _hoje, horario: '11:00', status: StatusAgendamento.confirmado)).called(1);
    });
  });

  // ===================================================================== status desconhecido (parse)
  group('Status desconhecido (parse)', () {
    test('fromJson de Meus e da Agenda: valores estranhos viram desconhecido, conhecidos com caixa/espaço não', () {
      for (final v in ['NO_SHOW', '', 123, null, 'PENDENTES', 'DESCONHECIDO', 'cancelad0']) {
        expect(MeuAgendamento.fromJson({'id': 1, 'data': '2030-01-20', 'horario': '09:00', 'status': v, 'servico': 'x'}).status,
            StatusAgendamento.desconhecido,
            reason: '$v');
      }
      expect(StatusAgendamento.deApi(' confirmado\n'), StatusAgendamento.confirmado);
      expect(StatusAgendamento.desconhecido.ocupaHorario, isTrue);
    });
  });

  // ===================================================================== Meus Agendamentos
  group('Meus Agendamentos: desconhecido e corrida no cancelar', () {
    late SessionController session;

    setUp(() async {
      session = SessionController(FakeTokenStorage());
      await session.iniciar('t', const Usuario(id: 3, nome: 'Maria', role: 'CLIENTE'));
    });

    Widget montar(MeusAgendamentosController c) => comRouter(const MeusAgendamentosPage(), providers: [
          ChangeNotifierProvider<SessionController>.value(value: session),
          ChangeNotifierProvider.value(value: c),
        ]);

    testWidgets('desconhecido futuro vai para o Histórico, sem botão de cancelar', (tester) async {
      when(() => agenda.meus()).thenAnswer((_) async => [
            meu(1, DateTime(2030, 2, 1), '09:00', StatusAgendamento.desconhecido),
            meu(2, DateTime(2030, 2, 2), '09:00', StatusAgendamento.pendente),
          ]);
      await tester.pumpWidget(montar(MeusAgendamentosController(agenda, relogio: _relogio)));
      await tester.pumpAndSettle();
      expect(find.text('Próximos (1)'), findsOneWidget);
      expect(find.text('Histórico (1)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('aba-historico')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('meu-agendamento-1')), findsOneWidget);
      expect(find.text('Desconhecido'), findsOneWidget);
      expect(find.byKey(const Key('botao-cancelar-1')), findsNothing);
    });

    testWidgets('com um cancelamento em andamento os outros botões ficam desabilitados e não chamam a API',
        (tester) async {
      final pendente = Completer<void>();
      when(() => agenda.meus()).thenAnswer((_) async => [
            meu(1, DateTime(2030, 2, 1), '09:00', StatusAgendamento.pendente),
            meu(2, DateTime(2030, 2, 2), '09:00', StatusAgendamento.confirmado),
          ]);
      when(() => agenda.cancelar(1)).thenAnswer((_) => pendente.future);
      await tester.pumpWidget(montar(MeusAgendamentosController(agenda, relogio: _relogio)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('botao-cancelar-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dialogo-sim')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // diálogo termina de fechar; cancelamento segue pendente
      expect(find.byType(AlertDialog), findsNothing);
      for (final id in [1, 2]) {
        expect(tester.widget<TextButton>(find.byKey(Key('botao-cancelar-$id'))).onPressed, isNull, reason: '$id');
      }
      await tester.tap(find.byKey(const Key('botao-cancelar-2')), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(AlertDialog), findsNothing);
      pendente.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('snack-sucesso')), findsOneWidget);
      verify(() => agenda.cancelar(1)).called(1);
      verifyNever(() => agenda.cancelar(2));
      verify(() => agenda.meus()).called(2);
    });

    test('cancelar o MESMO agendamento duas vezes em paralelo: o segundo é "Aguarde" e a API é chamada 1 vez', () async {
      final pendente = Completer<void>();
      when(() => agenda.meus()).thenAnswer((_) async => const []);
      when(() => agenda.cancelar(any())).thenAnswer((_) => pendente.future);
      final c = MeusAgendamentosController(agenda, relogio: _relogio);
      final a = meu(1, DateTime(2030, 2, 1), '09:00', StatusAgendamento.pendente);
      final f1 = c.cancelar(a);
      final f2 = c.cancelar(a);
      expect(c.cancelando, 1);
      expect(await f2, MeusAgendamentosController.mensagemAguarde);
      expect(await f2, isNotNull);
      pendente.complete();
      expect(await f1, isNull);
      expect(c.cancelando, isNull);
      verify(() => agenda.cancelar(1)).called(1);
    });

    test('depois de um cancelamento que FALHOU, um novo cancelamento é aceito (a trava é liberada)', () async {
      when(() => agenda.meus()).thenAnswer((_) async => const []);
      var n = 0;
      when(() => agenda.cancelar(any())).thenAnswer((_) async {
        if (n++ == 0) throw const ApiException(tipo: ApiErrorTipo.semConexao, mensagem: 'Sem conexão com o servidor');
      });
      final c = MeusAgendamentosController(agenda, relogio: _relogio);
      final a = meu(1, DateTime(2030, 2, 1), '09:00', StatusAgendamento.pendente);
      expect(await c.cancelar(a), 'Sem conexão com o servidor');
      expect(c.cancelando, isNull);
      expect(await c.cancelar(a), isNull);
      verify(() => agenda.cancelar(1)).called(2);
    });

    test('sair da tela durante o cancelamento: termina sem exceção e não recarrega depois do dispose', () async {
      final pendente = Completer<void>();
      when(() => agenda.meus()).thenAnswer((_) async => const []);
      when(() => agenda.cancelar(any())).thenAnswer((_) => pendente.future);
      final c = MeusAgendamentosController(agenda, relogio: _relogio);
      final f = c.cancelar(meu(1, DateTime(2030, 2, 1), '09:00', StatusAgendamento.pendente));
      c.dispose();
      pendente.complete();
      expect(await f, isNull);
      verifyNever(() => agenda.meus());
    });

    test('Agenda Admin: segunda ação durante a primeira devolve erro "Aguarde" (não sucesso) e não chama a API',
        () async {
      final pendente = Completer<void>();
      when(() => admin.cancelar(any())).thenAnswer((_) => pendente.future);
      when(() => admin.excluir(any())).thenAnswer((_) async {});
      final c = AgendaAdminController(admin, relogio: _relogio);
      final a = ag(1, '11:00', StatusAgendamento.pendente);
      final f1 = c.cancelar(a);
      final r2 = await c.excluir(a);
      expect(r2.sucesso, isFalse);
      final r3 = await c.cancelar(a);
      expect(r3.sucesso, isFalse);
      pendente.complete();
      expect((await f1).sucesso, isTrue);
      verify(() => admin.cancelar(1)).called(1);
      verifyNever(() => admin.excluir(any()));
    });
  });
}
