// FASE 3, volta 3 (tester): limites do calendário da Agenda Admin (extremos, virada da meia-noite,
// invariante first <= initial <= last), "Hoje"/"Amanhã" recalculados no carregar (lista antiga
// descartada, resposta atrasada ignorada) e selectableDayPredicate da edição.
import 'dart:async';

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
import 'package:cortecerto_flutter/features/servicos/data/servicos_api.dart';
import 'package:cortecerto_flutter/features/servicos/domain/servico.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../helpers/fakes.dart';

const _servico = Servico(id: 1, tipoServico: 'Corte Simples', precoServico: '35.00');
final _hoje = DateTime(2030, 1, 15);

DateTime _agora = DateTime(2030, 1, 15, 10, 10);
DateTime _relogio() => _agora;

DateTime _d(DateTime base, int dias) => DateTime(base.year, base.month, base.day + dias);
DateTime _soData(DateTime d) => DateTime(d.year, d.month, d.day);

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
    when(() => agenda.disponibilidades(any())).thenAnswer((_) async => ['08:00', '10:00', '19:30']);
    when(() => admin.listar(any())).thenAnswer((_) async => const []);
  });

  AgendaAdminController agendaCtrl() => AgendaAdminController(admin, relogio: _relogio);

  AgendamentoFormController form(AgendamentoFormArgs args) => AgendamentoFormController(
        adminApi: admin,
        clientesApi: clientes,
        agendamentoApi: agenda,
        servicosApi: servicos,
        args: args,
        relogio: _relogio,
      );

  void invarianteAgenda(AgendaAdminController c, String caso) {
    final p = c.primeiroDiaCalendario, i = c.diaInicialCalendario, u = c.ultimoDiaCalendario;
    expect(!p.isAfter(i) && !i.isAfter(u), isTrue, reason: '$caso: first=$p initial=$i last=$u');
    expect(i, c.dia, reason: '$caso: initialDate deve ser o próprio dia exibido');
    expect(!p.isAfter(_d(c.hoje, -365)), isTrue, reason: '$caso: firstDate > hoje-365');
    expect(!u.isBefore(_d(c.hoje, 365)), isTrue, reason: '$caso: lastDate < hoje+365');
    for (final d in [p, i, u]) {
      expect(d, _soData(d), reason: '$caso: data com hora ($d)');
    }
  }

  // ===================================================================== Agenda: limites
  group('Agenda Admin: limites do calendário "Data"', () {
    test('c.dia exatamente nos extremos (hoje-365 e hoje+365): limites fixos, initial = dia', () async {
      final c = agendaCtrl();
      for (final dia in [_d(_hoje, -365), _d(_hoje, 365)]) {
        await c.selecionarData(dia);
        expect(c.periodo, PeriodoAgenda.data);
        expect(c.primeiroDiaCalendario, _d(_hoje, -365));
        expect(c.ultimoDiaCalendario, _d(_hoje, 365));
        expect(c.diaInicialCalendario, dia);
      }
    });

    test('c.dia além dos extremos (hoje-366/hoje+366, ex.: chegou por código): o intervalo se estende', () async {
      final c = agendaCtrl();
      await c.selecionarData(_d(_hoje, -366));
      expect(c.primeiroDiaCalendario, _d(_hoje, -366));
      expect(c.ultimoDiaCalendario, _d(_hoje, 365));
      invarianteAgenda(c, '-366');
      await c.selecionarData(_d(_hoje, 366));
      expect(c.primeiroDiaCalendario, _d(_hoje, -365));
      expect(c.ultimoDiaCalendario, _d(_hoje, 366));
      invarianteAgenda(c, '+366');
    });

    test('virada exata: 23:59:59.999 → 00:00:00.000 com o dia mais antigo e com o mais distante', () async {
      _agora = DateTime(2030, 1, 15, 23, 59, 59, 999);
      final c = agendaCtrl();
      await c.selecionarData(_d(_hoje, -365));
      expect(c.hoje, _hoje);
      _agora = DateTime(2030, 1, 16);
      expect(c.hoje, DateTime(2030, 1, 16));
      expect(c.primeiroDiaCalendario, _d(_hoje, -365), reason: 'firstDate acompanha o dia exibido');
      expect(c.diaInicialCalendario, _d(_hoje, -365));
      expect(c.ultimoDiaCalendario, DateTime(2031, 1, 16));
      invarianteAgenda(c, 'meia-noite, dia antigo');

      _agora = DateTime(2030, 1, 15, 23, 59, 59, 999);
      await c.selecionarData(_d(_hoje, 365));
      _agora = DateTime(2030, 1, 16);
      expect(c.diaInicialCalendario, _d(_hoje, 365));
      expect(c.ultimoDiaCalendario, DateTime(2031, 1, 16));
      expect(c.primeiroDiaCalendario, DateTime(2029, 1, 16));
      invarianteAgenda(c, 'meia-noite, dia distante');
    });

    test('app aberto por dias (relógio salta 10 dias para frente e 400 para trás): initial sempre dentro', () async {
      final c = agendaCtrl();
      await c.selecionarData(_d(_hoje, -365));
      _agora = DateTime(2030, 1, 25, 9);
      invarianteAgenda(c, '+10 dias');
      expect(c.periodo, PeriodoAgenda.data);
      _agora = DateTime(2028, 12, 11, 9);
      invarianteAgenda(c, '-400 dias');
    });

    test('invariante first <= initial(=dia) <= last: relógios em bordas de mês/ano/bissexto × dias', () async {
      final relogios = [
        DateTime(2030, 1, 15, 0, 0),
        DateTime(2030, 12, 31, 23, 59, 59, 999),
        DateTime(2031, 1, 1, 0, 0),
        DateTime(2032, 2, 29, 12),
        DateTime(2032, 3, 1, 0, 0, 0, 1),
        DateTime(2031, 2, 28, 23, 59),
        DateTime(2030, 10, 20, 0, 30), // antiga data de horário de verão no Brasil
        DateTime(2030, 2, 17, 0, 30),
      ];
      var casos = 0;
      for (final abertura in relogios) {
        for (final delta in [-400, -366, -365, -364, -1, 0, 1, 2, 364, 365, 366, 800]) {
          _agora = abertura;
          final c = agendaCtrl();
          await c.selecionarData(_d(abertura, delta));
          for (final depois in [abertura, abertura.add(const Duration(hours: 1)), _d(abertura, 1), _d(abertura, -1)]) {
            _agora = depois;
            invarianteAgenda(c, 'abertura=$abertura delta=$delta agora=$depois');
            casos++;
          }
        }
      }
      expect(casos, relogios.length * 12 * 4);
    });

    testWidgets('widget: dia mais antigo e virada exata da meia-noite → o calendário abre com initial = dia',
        (tester) async {
      _agora = DateTime(2030, 1, 15, 23, 59, 59, 999);
      final c = agendaCtrl();
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: c,
        child: MaterialApp(theme: AppTheme.darkTheme, home: const AgendaAdminPage()),
      ));
      await tester.pumpAndSettle();
      await c.selecionarData(_d(_hoje, -365));
      await tester.pumpAndSettle();
      _agora = DateTime(2030, 1, 16);
      await tocar(tester, find.byKey(const Key('periodo-data')));
      expect(tester.takeException(), isNull);
      final d = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
      expect(d.initialDate, _d(_hoje, -365));
      expect(d.firstDate, _d(_hoje, -365));
      expect(d.lastDate, DateTime(2031, 1, 16));
      // confirmar o dia inicial mantém o mesmo dia e o período "Data"
      await tocar(tester, find.text('OK'));
      expect(c.dia, _d(_hoje, -365));
      expect(c.periodo, PeriodoAgenda.data);
    });

    testWidgets('widget: escolher no calendário o NOVO hoje depois da meia-noite vira período "Hoje"',
        (tester) async {
      _agora = DateTime(2030, 1, 15, 23, 59);
      final c = agendaCtrl();
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: c,
        child: MaterialApp(theme: AppTheme.darkTheme, home: const AgendaAdminPage()),
      ));
      await tester.pumpAndSettle();
      await c.selecionarData(DateTime(2030, 1, 20));
      await tester.pumpAndSettle();
      _agora = DateTime(2030, 1, 16, 0, 1);
      await tocar(tester, find.byKey(const Key('periodo-data')));
      await tocar(tester, find.text('16'));
      await tocar(tester, find.text('OK'));
      expect(c.periodo, PeriodoAgenda.hoje);
      expect(c.dia, DateTime(2030, 1, 16));
    });
  });

  // ===================================================================== Agenda: Hoje/Amanhã
  group('Agenda Admin: "Hoje"/"Amanhã" recalculados no carregar', () {
    test('"Hoje" com lista às 23:59; carregar às 00:01 busca o novo dia e a lista antiga some JÁ no carregamento',
        () async {
      _agora = DateTime(2030, 1, 15, 23, 59);
      when(() => admin.listar(_hoje))
          .thenAnswer((_) async => [ag(1, '10:00', StatusAgendamento.confirmado, nome: 'Ontem')]);
      final c = agendaCtrl();
      await c.carregar();
      expect(c.agendamentos, hasLength(1));

      final pendente = Completer<List<AgendamentoAdmin>>();
      when(() => admin.listar(DateTime(2030, 1, 16))).thenAnswer((_) => pendente.future);
      _agora = DateTime(2030, 1, 16, 0, 1);
      final f = c.carregar();
      expect(c.dia, DateTime(2030, 1, 16));
      expect(c.periodo, PeriodoAgenda.hoje);
      expect(c.agendamentos, isEmpty, reason: 'lista de ontem não pode aparecer como "Hoje"');
      expect(c.carregou, isFalse);
      expect(c.slots.every((s) => s.disponivel), isTrue);
      pendente.complete([ag(2, '09:00', StatusAgendamento.pendente, data: DateTime(2030, 1, 16), nome: 'Novo')]);
      await f;
      expect(c.agendamentos.single.nomeCliente, 'Novo');
      verify(() => admin.listar(DateTime(2030, 1, 16))).called(1);
    });

    test('virada + falha na busca do novo dia: erro, e nenhum dado de ontem fica na tela', () async {
      _agora = DateTime(2030, 1, 15, 23, 59);
      when(() => admin.listar(_hoje))
          .thenAnswer((_) async => [ag(1, '10:00', StatusAgendamento.confirmado)]);
      final c = agendaCtrl();
      await c.carregar();
      when(() => admin.listar(DateTime(2030, 1, 16))).thenThrow(Exception('rede'));
      _agora = DateTime(2030, 1, 16, 0, 1);
      await c.carregar();
      expect(c.erro, isNotNull);
      expect(c.agendamentos, isEmpty);
      expect(c.carregou, isFalse);
      expect(c.total, 0);
      expect(c.contar(StatusAgendamento.confirmado), 0);
    });

    test('resposta atrasada de ONTEM (iniciada antes da meia-noite) é descartada se chegar depois da nova', () async {
      _agora = DateTime(2030, 1, 15, 23, 59);
      final ontem = Completer<List<AgendamentoAdmin>>();
      final hoje = Completer<List<AgendamentoAdmin>>();
      when(() => admin.listar(_hoje)).thenAnswer((_) => ontem.future);
      when(() => admin.listar(DateTime(2030, 1, 16))).thenAnswer((_) => hoje.future);
      final c = agendaCtrl();
      final f1 = c.carregar();
      _agora = DateTime(2030, 1, 16, 0, 1);
      final f2 = c.carregar();
      hoje.complete([ag(2, '09:00', StatusAgendamento.pendente, data: DateTime(2030, 1, 16), nome: 'Novo')]);
      await f2;
      ontem.complete([ag(1, '10:00', StatusAgendamento.confirmado, nome: 'Ontem')]);
      await f1;
      expect(c.dia, DateTime(2030, 1, 16));
      expect(c.agendamentos.single.nomeCliente, 'Novo');
      expect(c.isLoading, isFalse);
    });

    test('mesmo dia: recarregar NÃO zera a lista enquanto busca (só descarta quando o dia muda)', () async {
      when(() => admin.listar(_hoje)).thenAnswer((_) async => [ag(1, '10:00', StatusAgendamento.confirmado)]);
      final c = agendaCtrl();
      await c.carregar();
      final pendente = Completer<List<AgendamentoAdmin>>();
      when(() => admin.listar(_hoje)).thenAnswer((_) => pendente.future);
      _agora = DateTime(2030, 1, 15, 23, 59, 59, 999);
      final f = c.carregar();
      expect(c.agendamentos, hasLength(1));
      expect(c.carregou, isTrue);
      pendente.complete(const []);
      await f;
    });

    test('ação (confirmar) feita depois da meia-noite recarrega o NOVO dia', () async {
      _agora = DateTime(2030, 1, 15, 23, 58);
      final a = ag(1, '19:30', StatusAgendamento.pendente);
      when(() => admin.listar(any())).thenAnswer((_) async => const []);
      when(() => admin.listar(_hoje)).thenAnswer((_) async => [a]);
      when(() => admin.atualizar(any(), status: any(named: 'status'))).thenAnswer((_) async => a);
      final c = agendaCtrl();
      await c.carregar();
      _agora = DateTime(2030, 1, 16, 0, 2);
      final r = await c.confirmar(a);
      expect(r.sucesso, isTrue);
      expect(c.dia, DateTime(2030, 1, 16));
      expect(c.agendamentos, isEmpty);
      final dias = verify(() => admin.listar(captureAny())).captured;
      expect(dias.last, DateTime(2030, 1, 16));
    });

    test('"Amanhã" na virada do ano: 31/12 23:59 → 01/01 00:01 busca 02/01', () async {
      _agora = DateTime(2030, 12, 31, 23, 59);
      final c = agendaCtrl();
      await c.selecionarAmanha();
      expect(c.dia, DateTime(2031, 1, 1));
      _agora = DateTime(2031, 1, 1, 0, 1);
      await c.carregar();
      expect(c.dia, DateTime(2031, 1, 2));
      expect(c.periodo, PeriodoAgenda.amanha);
      final dias = verify(() => admin.listar(captureAny())).captured;
      expect(dias.last, DateTime(2031, 1, 2));
    });

    test('"Data" no limite hoje-365 + virada: carregar não mexe no dia nem no período', () async {
      final c = agendaCtrl();
      await c.selecionarData(_d(_hoje, -365));
      _agora = DateTime(2030, 1, 16, 0, 1);
      await c.carregar();
      expect(c.dia, _d(_hoje, -365));
      expect(c.periodo, PeriodoAgenda.data);
    });

    testWidgets('widget: tela "Hoje" aberta às 23:59; depois da meia-noite, recarregar troca os dados do dia',
        (tester) async {
      _agora = DateTime(2030, 1, 15, 23, 59);
      when(() => admin.listar(any())).thenAnswer((inv) async {
        final dia = inv.positionalArguments.first as DateTime;
        return dia == _hoje
            ? [ag(1, '10:00', StatusAgendamento.confirmado, nome: 'Cliente Ontem')]
            : <AgendamentoAdmin>[];
      });
      final c = agendaCtrl();
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: c,
        child: MaterialApp(theme: AppTheme.darkTheme, home: const AgendaAdminPage()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Cliente Ontem'), findsWidgets);
      _agora = DateTime(2030, 1, 16, 0, 1);
      await c.carregar();
      await tester.pumpAndSettle();
      expect(find.text('Cliente Ontem'), findsNothing);
      expect(c.dia, DateTime(2030, 1, 16));
      expect(find.textContaining('Hoje'), findsWidgets);
      expect(find.text('Horário encerrado'), findsNothing, reason: 'às 00:01 todos os horários do novo dia são futuros');
    });
  });

  // ===================================================================== Edição: selectableDayPredicate
  group('Formulário admin: selectableDayPredicate da edição', () {
    test('edição de um passado: original (com ou sem hora) sim; passados no meio e ontem não; hoje em diante sim',
        () {
      final original = _d(_hoje, -10);
      final c = form(AgendamentoFormArgs.editar(ag(1, '10:00', StatusAgendamento.realizado, data: original)));
      expect(c.diaSelecionavel(original), isTrue);
      expect(c.diaSelecionavel(original.add(const Duration(hours: 15, minutes: 30))), isTrue);
      expect(c.diaSelecionavel(_d(_hoje, -11)), isFalse);
      expect(c.diaSelecionavel(_d(_hoje, -9)), isFalse);
      expect(c.diaSelecionavel(_d(_hoje, -1)), isFalse);
      expect(c.diaSelecionavel(_d(_hoje, -1).add(const Duration(hours: 23, minutes: 59))), isFalse);
      expect(c.diaSelecionavel(_hoje), isTrue);
      expect(c.diaSelecionavel(_hoje.add(const Duration(hours: 23))), isTrue);
      expect(c.diaSelecionavel(_d(_hoje, 400)), isTrue);
      expect(c.diaSelecionavel(c.diaInicialCalendario), isTrue);
    });

    test('edição: escolher outra data mantém a original selecionável (voltar atrás é possível)', () async {
      final original = _d(_hoje, -3);
      final c = form(AgendamentoFormArgs.editar(ag(1, '10:00', StatusAgendamento.confirmado, data: original)));
      await c.selecionarData(_d(_hoje, 5));
      expect(c.diaSelecionavel(original), isTrue);
      expect(c.diaSelecionavel(_d(_hoje, 5)), isTrue);
      expect(c.diaSelecionavel(_d(_hoje, -2)), isFalse);
      expect(c.diaSelecionavel(c.diaInicialCalendario), isTrue);
    });

    test('edição aberta antes da meia-noite: depois dela a original e a selecionada (agora passadas) continuam',
        () async {
      _agora = DateTime(2030, 1, 15, 23, 50);
      final c = form(AgendamentoFormArgs.editar(ag(1, '19:30', StatusAgendamento.confirmado, data: _hoje)));
      await c.selecionarData(_d(_hoje, 1)); // 16/01
      _agora = DateTime(2030, 1, 17, 0, 5); // dois dias depois: 15 e 16 ficaram no passado
      expect(c.diaSelecionavel(_hoje), isTrue, reason: 'original');
      expect(c.diaSelecionavel(_d(_hoje, 1)), isTrue, reason: 'selecionada');
      expect(c.diaSelecionavel(_d(_hoje, -1)), isFalse);
      expect(c.diaSelecionavel(DateTime(2030, 1, 17)), isTrue);
      expect(c.diaSelecionavel(c.diaInicialCalendario), isTrue);
    });

    test('criação: o predicado aceita tudo, mas o intervalo começa em hoje (sem dia passado alcançável)', () {
      final c = form(AgendamentoFormArgs.criar(data: _d(_hoje, -5)));
      expect(c.diaSelecionavel(_d(_hoje, -1)), isTrue);
      expect(c.primeiroDiaCalendario, _hoje);
      expect(c.diaInicialCalendario, _hoje);
    });

    test('invariante do showDatePicker: predicado(initialDate) é sempre true (edição, vários relógios/datas)',
        () async {
      var casos = 0;
      for (final abertura in [DateTime(2030, 1, 15, 10), DateTime(2030, 12, 31, 23, 59), DateTime(2032, 2, 29, 0, 1)]) {
        for (final dOrig in [-800, -366, -1, 0, 1, 365, 366, 900]) {
          for (final dSel in [null, 0, 1, 30, 365]) {
            _agora = abertura;
            final c = form(AgendamentoFormArgs.editar(
                ag(1, '10:00', StatusAgendamento.confirmado, data: _d(abertura, dOrig))));
            if (dSel != null) await c.selecionarData(_d(abertura, dSel));
            for (final depois in [abertura, _d(abertura, 1), _d(abertura, 3).add(const Duration(minutes: 1))]) {
              _agora = depois;
              final i = c.diaInicialCalendario;
              final caso = 'abertura=$abertura orig=$dOrig sel=$dSel agora=$depois';
              expect(c.diaSelecionavel(i), isTrue, reason: caso);
              expect(!c.primeiroDiaCalendario.isAfter(i) && !i.isAfter(c.ultimoDiaCalendario), isTrue, reason: caso);
              expect(c.diaSelecionavel(_d(c.hoje, -1)),
                  _d(c.hoje, -1) == _soData(c.args.data) || _d(c.hoje, -1) == c.data,
                  reason: '$caso: ontem só se for a original/selecionada');
              casos++;
            }
          }
        }
      }
      expect(casos, 3 * 8 * 5 * 3);
    });

    group('widget (formulário real)', () {
      late SessionController session;

      setUp(() async {
        session = SessionController(FakeTokenStorage());
        await session.iniciar('t', const Usuario(id: 9, nome: 'Chefe', role: 'ADMIN'));
      });

      Future<void> abrirForm(WidgetTester tester, AgendamentoFormArgs args) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.5;
        addTearDown(tester.view.reset);
        final router = GoRouter(routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => ChangeNotifierProvider(
              create: (_) => form(args),
              child: const AgendamentoFormPage(),
            ),
          ),
          GoRoute(path: Rotas.adminAgendamentoForm, builder: (_, _) => const SizedBox()),
        ]);
        await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<SessionController>.value(value: session),
            Provider<AdminAgendamentoApi>.value(value: admin),
            Provider<ClientesApi>.value(value: clientes),
            Provider<AgendamentoApi>.value(value: agenda),
            Provider<ServicosApi>.value(value: servicos),
          ],
          child: MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
        ));
        await tester.pumpAndSettle();
      }

      AgendamentoFormController fc(WidgetTester tester) =>
          tester.element(find.byType(AgendamentoFormPage)).read<AgendamentoFormController>();

      testWidgets('edição de 05/01 com hoje 15/01: tocar 08/01 (passado) não muda nada; tocar 20/01 muda',
          (tester) async {
        final original = DateTime(2030, 1, 5);
        await abrirForm(tester, AgendamentoFormArgs.editar(ag(1, '10:00', StatusAgendamento.realizado, data: original)));
        await tocar(tester, find.byKey(const Key('form-botao-data')));
        expect(tester.takeException(), isNull);
        final d = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
        expect(d.selectableDayPredicate, isNotNull);
        expect(d.selectableDayPredicate!(original), isTrue);
        expect(d.selectableDayPredicate!(DateTime(2030, 1, 8)), isFalse);
        await tocar(tester, find.text('8'));
        await tocar(tester, find.text('OK'));
        expect(fc(tester).data, original, reason: 'dia passado desabilitado não pode ser escolhido');

        await tocar(tester, find.byKey(const Key('form-botao-data')));
        await tocar(tester, find.text('20'));
        await tocar(tester, find.text('OK'));
        expect(fc(tester).data, DateTime(2030, 1, 20));
        verify(() => agenda.disponibilidades(DateTime(2030, 1, 20))).called(greaterThanOrEqualTo(1));
        verifyNever(() => agenda.disponibilidades(DateTime(2030, 1, 8)));
      });

      testWidgets('edição de HOJE aberta às 23:50; às 00:05 o calendário abre sem assert (original virou ontem)',
          (tester) async {
        _agora = DateTime(2030, 1, 15, 23, 50);
        await abrirForm(tester, AgendamentoFormArgs.editar(ag(1, '19:30', StatusAgendamento.confirmado, data: _hoje)));
        _agora = DateTime(2030, 1, 16, 0, 5);
        await tocar(tester, find.byKey(const Key('form-botao-data')));
        expect(tester.takeException(), isNull);
        final d = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
        expect(d.initialDate, _hoje);
        expect(d.firstDate, _hoje);
        expect(d.selectableDayPredicate!(d.initialDate!), isTrue);
        expect(d.selectableDayPredicate!(DateTime(2030, 1, 16)), isTrue);
        expect(d.lastDate, DateTime(2031, 1, 16));
      });
    });
  });
}
