// FASE 3, volta 2 (developer): limites do calendário do formulário admin (relógio injetável),
// criação sem data/horário passado, "+" desabilitado em horário passado, status desconhecido
// e corrida no cancelar de Meus Agendamentos.
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
import 'package:cortecerto_flutter/features/meus_agendamentos/domain/meu_agendamento.dart';
import 'package:cortecerto_flutter/features/meus_agendamentos/presentation/meus_agendamentos_controller.dart';
import 'package:cortecerto_flutter/features/servicos/data/servicos_api.dart';
import 'package:cortecerto_flutter/features/servicos/domain/servico.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../helpers/fakes.dart';

const _servico = Servico(id: 1, tipoServico: 'Corte Simples', precoServico: '35.00');

/// "Agora" fixo dos testes: 15/01/2030 às 10:10.
final _agora = DateTime(2030, 1, 15, 10, 10);
DateTime _relogio() => _agora;

AgendamentoAdmin ag(int id, String horario, StatusAgendamento status, {DateTime? data}) => AgendamentoAdmin(
      id: id,
      data: data ?? DateTime(2030, 1, 15),
      horario: horario,
      status: status,
      servicoId: 1,
      servico: 'Corte Simples',
      clienteId: id * 10,
      nomeCliente: 'Cliente $id',
    );

Future<void> tocar(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(DateTime(2030));
    registerFallbackValue(StatusAgendamento.pendente);
  });

  late MockAdminAgendamentoApi admin;
  late MockClientesApi clientes;
  late MockAgendamentoApi agenda;
  late MockServicosApi servicos;

  setUp(() {
    admin = MockAdminAgendamentoApi();
    clientes = MockClientesApi();
    agenda = MockAgendamentoApi();
    servicos = MockServicosApi();
    when(() => servicos.listar()).thenAnswer((_) async => const [_servico]);
    when(() => agenda.disponibilidades(any())).thenAnswer((_) async => ['09:00', '10:00', '10:30', '11:00']);
  });

  AgendamentoFormController form(AgendamentoFormArgs args) => AgendamentoFormController(
      adminApi: admin,
      clientesApi: clientes,
      agendamentoApi: agenda,
      servicosApi: servicos,
      args: args,
      relogio: _relogio);

  group('Formulário admin: limites do calendário', () {
    final hoje = DateTime(2030, 1, 15);
    final hojeMais365 = hoje.add(const Duration(days: 365));

    test('editar agendamento a mais de 1 ano: lastDate = data do agendamento e initialDate dentro', () {
      final longe = DateTime(2032, 3, 1);
      final c = form(AgendamentoFormArgs.editar(ag(1, '10:00', StatusAgendamento.confirmado, data: longe)));
      expect(c.ultimoDiaCalendario, longe);
      expect(c.primeiroDiaCalendario, hoje);
      expect(c.diaInicialCalendario, longe);
    });

    test('editar agendamento passado: firstDate = data do agendamento, lastDate = hoje+365', () {
      final passado = DateTime(2029, 12, 1);
      final c = form(AgendamentoFormArgs.editar(ag(1, '10:00', StatusAgendamento.realizado, data: passado)));
      expect(c.data, passado);
      expect(c.primeiroDiaCalendario, passado);
      expect(c.ultimoDiaCalendario, hojeMais365);
      expect(c.diaInicialCalendario, passado);
    });

    test('criar num dia passado: começa em hoje, sem horário, firstDate = hoje', () {
      final c = form(AgendamentoFormArgs.criar(data: DateTime(2030, 1, 10), horario: '09:00'));
      expect(c.data, hoje);
      expect(c.horario, isNull);
      expect(c.primeiroDiaCalendario, hoje);
      expect(c.ultimoDiaCalendario, hojeMais365);
      expect(c.diaInicialCalendario, hoje);
    });

    test('criar num dia futuro: mantém data e horário', () {
      final c = form(AgendamentoFormArgs.criar(data: DateTime(2030, 2, 1), horario: '09:00'));
      expect(c.data, DateTime(2030, 2, 1));
      expect(c.horario, '09:00');
      expect(c.primeiroDiaCalendario, hoje);
    });
  });

  group('Formulário admin: horários passados na criação', () {
    test('hoje: horário já passado vindo da grade é descartado e some da lista', () async {
      final c = form(AgendamentoFormArgs.criar(data: DateTime(2030, 1, 15), horario: '09:00'));
      expect(c.horario, isNull);
      await c.iniciar();
      expect(c.horarios, ['10:30', '11:00']); // 09:00 e 10:00 já passaram às 10:10
    });

    test('hoje: horário futuro vindo da grade continua selecionado', () async {
      final c = form(AgendamentoFormArgs.criar(data: DateTime(2030, 1, 15), horario: '10:30'));
      await c.iniciar();
      expect(c.horario, '10:30');
    });

    test('edição não filtra (o horário atual do próprio agendamento continua oferecido)', () async {
      final c = form(AgendamentoFormArgs.editar(ag(1, '09:00', StatusAgendamento.confirmado)));
      await c.iniciar();
      expect(c.horarios, contains('09:00'));
      expect(c.horario, '09:00');
    });
  });

  group('Status desconhecido', () {
    test('deApi: valor desconhecido não vira PENDENTE', () {
      expect(StatusAgendamento.deApi('NO_SHOW'), StatusAgendamento.desconhecido);
      expect(StatusAgendamento.deApi(null), StatusAgendamento.desconhecido);
      expect(StatusAgendamento.deApi('pendente'), StatusAgendamento.pendente);
      expect(StatusAgendamento.deApi(' REALIZADO '), StatusAgendamento.realizado);
      expect(StatusAgendamento.conhecidos, isNot(contains(StatusAgendamento.desconhecido)));
    });

    test('formulário: não oferece o desconhecido e não o reenvia ao salvar', () async {
      when(() => admin.atualizar(any(),
              servicoId: any(named: 'servicoId'),
              data: any(named: 'data'),
              horario: any(named: 'horario'),
              status: any(named: 'status')))
          .thenAnswer((_) async => ag(1, '11:00', StatusAgendamento.confirmado));
      final c = form(AgendamentoFormArgs.editar(
          ag(1, '11:00', StatusAgendamento.desconhecido, data: DateTime(2030, 1, 20))));
      await c.iniciar();
      expect(c.statusDisponiveis, isNot(contains(StatusAgendamento.desconhecido)));
      expect(await c.salvar(), isTrue);
      verify(() => admin.atualizar(1,
          servicoId: 1, data: DateTime(2030, 1, 20), horario: '11:00', status: null)).called(1);
    });
  });

  group('Meus Agendamentos: corrida no cancelar', () {
    test('segundo cancelar durante o primeiro devolve "Aguarde" (não sucesso) e não chama a API', () async {
      final api = MockAgendamentoApi();
      final pendente = Completer<void>();
      when(() => api.meus()).thenAnswer((_) async => const []);
      when(() => api.cancelar(any())).thenAnswer((_) => pendente.future);
      final c = MeusAgendamentosController(api, relogio: _relogio);
      final a = MeuAgendamento(
          id: 1, data: DateTime(2030, 1, 20), horario: '09:00', status: StatusAgendamento.pendente, servico: 'Corte');
      final b = MeuAgendamento(
          id: 2, data: DateTime(2030, 1, 21), horario: '09:00', status: StatusAgendamento.pendente, servico: 'Corte');
      final primeiro = c.cancelar(a);
      expect(await c.cancelar(b), MeusAgendamentosController.mensagemAguarde);
      pendente.complete();
      expect(await primeiro, isNull);
      verify(() => api.cancelar(1)).called(1);
      verifyNever(() => api.cancelar(2));
    });
  });

  group('Agenda Admin: horário passado', () {
    test('horarioPassou usa o relógio e o dia exibido', () async {
      final api = MockAdminAgendamentoApi();
      when(() => api.listar(any())).thenAnswer((_) async => const []);
      final c = AgendaAdminController(api, relogio: _relogio);
      expect(c.horarioPassou('09:30'), isTrue);
      expect(c.horarioPassou('10:00'), isTrue);
      expect(c.horarioPassou('10:30'), isFalse);
      await c.selecionarAmanha();
      expect(c.horarioPassou('08:00'), isFalse);
      await c.selecionarData(DateTime(2030, 1, 10));
      expect(c.horarioPassou('19:30'), isTrue);
    });
  });

  group('Widgets', () {
    late SessionController session;

    setUp(() async {
      session = SessionController(FakeTokenStorage());
      await session.iniciar('t', const Usuario(id: 9, nome: 'Chefe', role: 'ADMIN'));
    });

    Widget montar(List<AgendamentoAdmin> doDia) {
      when(() => admin.listar(any())).thenAnswer((_) async => doDia);
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

    Future<void> abrir(WidgetTester tester, List<AgendamentoAdmin> doDia) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(montar(doDia));
      await tester.pumpAndSettle();
    }

    Finder em(String horario, Finder f) =>
        find.descendant(of: find.byKey(Key('agenda-horario-$horario')), matching: f);

    testWidgets('grade de hoje: horário passado fica "Horário encerrado", sem "+", e tocar não abre o form',
        (tester) async {
      await abrir(tester, const []);
      expect(em('09:30', find.text('Horário encerrado')), findsOneWidget);
      expect(em('09:30', find.byKey(const Key('slot-adicionar'))), findsNothing);
      expect(em('10:30', find.text('Disponível')), findsOneWidget);
      expect(em('10:30', find.byKey(const Key('slot-adicionar'))), findsOneWidget);
      await tocar(tester, find.byKey(const Key('agenda-horario-09:30')));
      expect(find.text('Novo agendamento'), findsNothing);
      await tocar(tester, find.byKey(const Key('agenda-horario-10:30')));
      expect(find.text('Novo agendamento'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('form-horario-10:30'))).selected, isTrue);
    });

    testWidgets('editar agendamento 2 anos à frente abre o calendário com lastDate = data dele', (tester) async {
      final longe = DateTime(2032, 1, 1);
      when(() => agenda.disponibilidades(any())).thenAnswer((_) async => ['10:00']);
      await abrir(tester, const []);
      // abre o formulário de edição direto pelo router
      final ctx = tester.element(find.byType(AgendaAdminPage));
      unawaited(GoRouter.of(ctx).pushNamed<bool>(Rotas.nomeAdminAgendamentoForm,
          extra: AgendamentoFormArgs.editar(ag(7, '10:00', StatusAgendamento.confirmado, data: longe))));
      await tester.pumpAndSettle();
      await tocar(tester, find.byKey(const Key('form-botao-data')));
      expect(tester.takeException(), isNull);
      final dialogo = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
      expect(dialogo.lastDate, longe);
      expect(dialogo.initialDate, longe);
      expect(dialogo.firstDate, DateTime(2030, 1, 15));
    });

    testWidgets('criar: o calendário começa em hoje (sem dias passados)', (tester) async {
      await abrir(tester, const []);
      await tocar(tester, find.byKey(const Key('botao-novo-agendamento')));
      await tocar(tester, find.byKey(const Key('form-botao-data')));
      final dialogo = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
      expect(dialogo.firstDate, DateTime(2030, 1, 15));
      expect(dialogo.lastDate, DateTime(2031, 1, 15));
    });
  });
}
