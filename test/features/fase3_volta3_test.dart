// FASE 3, volta 3 (developer): limites do calendário "Data" da Agenda Admin com relógio
// injetável (F2), "Hoje"/"Amanhã" recalculados depois da meia-noite (S7) e dias passados
// bloqueados no calendário de edição do formulário.
import 'package:cortecerto_flutter/core/theme/app_theme.dart';
import 'package:cortecerto_flutter/features/admin/domain/agendamento_admin.dart';
import 'package:cortecerto_flutter/features/admin/presentation/agenda_admin_controller.dart';
import 'package:cortecerto_flutter/features/admin/presentation/agenda_admin_page.dart';
import 'package:cortecerto_flutter/features/admin/presentation/agendamento_form_controller.dart';
import 'package:cortecerto_flutter/features/agendamento/domain/status_agendamento.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../helpers/fakes.dart';

AgendamentoAdmin ag(int id, DateTime data, {String horario = '10:00'}) => AgendamentoAdmin(
      id: id,
      data: data,
      horario: horario,
      status: StatusAgendamento.confirmado,
      servicoId: 1,
      servico: 'Corte Simples',
      clienteId: id * 10,
      nomeCliente: 'Cliente $id',
    );

void main() {
  setUpAll(() => registerFallbackValue(DateTime(2030)));

  late MockAdminAgendamentoApi admin;
  late DateTime agora;
  DateTime relogio() => agora;

  setUp(() {
    admin = MockAdminAgendamentoApi();
    agora = DateTime(2030, 1, 15, 23, 50);
    when(() => admin.listar(any())).thenAnswer((_) async => const []);
  });

  void invariante(AgendaAdminController c, String caso) {
    final first = c.primeiroDiaCalendario;
    final initial = c.diaInicialCalendario;
    final last = c.ultimoDiaCalendario;
    expect(!initial.isBefore(first), isTrue, reason: '$caso: initial $initial < first $first');
    expect(!initial.isAfter(last), isTrue, reason: '$caso: initial $initial > last $last');
    expect(initial, c.dia, reason: '$caso: o dia exibido deve ser o inicial');
  }

  group('Agenda Admin: limites do calendário "Data"', () {
    test('antes da meia-noite: [hoje-365, hoje+365] e initialDate = dia exibido', () async {
      final c = AgendaAdminController(admin, relogio: relogio);
      expect(c.primeiroDiaCalendario, DateTime(2029, 1, 15));
      expect(c.ultimoDiaCalendario, DateTime(2031, 1, 15));
      expect(c.diaInicialCalendario, DateTime(2030, 1, 15));
      invariante(c, 'hoje');
    });

    test('no dia mais antigo e o relógio vira a meia-noite: firstDate acompanha o dia exibido', () async {
      final c = AgendaAdminController(admin, relogio: relogio);
      await c.selecionarData(DateTime(2029, 1, 15));
      invariante(c, 'antes');
      agora = DateTime(2030, 1, 16, 0, 5);
      expect(c.primeiroDiaCalendario, DateTime(2029, 1, 15));
      expect(c.ultimoDiaCalendario, DateTime(2031, 1, 16));
      invariante(c, 'depois da meia-noite');
    });

    test('no dia mais distante e o relógio volta (ajuste de hora): lastDate acompanha o dia exibido', () async {
      final c = AgendaAdminController(admin, relogio: relogio);
      await c.selecionarData(DateTime(2031, 1, 15));
      agora = DateTime(2030, 1, 14, 9);
      expect(c.ultimoDiaCalendario, DateTime(2031, 1, 15));
      expect(c.primeiroDiaCalendario, DateTime(2029, 1, 14));
      invariante(c, 'relógio voltou');
    });

    test('invariante first <= initial <= last em várias combinações de dia e relógio', () async {
      for (final desloc in [-400, -366, -365, -1, 0, 1, 365, 366, 400]) {
        for (final passo in [-2, -1, 0, 1, 2, 30]) {
          agora = DateTime(2030, 1, 15, 12);
          final c = AgendaAdminController(admin, relogio: relogio);
          await c.selecionarData(DateTime(2030, 1, 15 + desloc));
          agora = DateTime(2030, 1, 15 + passo, 0, 1);
          invariante(c, 'desloc=$desloc passo=$passo');
        }
      }
    });

    test('virada de ano bissexto: soma por campos de data (sem Duration)', () async {
      agora = DateTime(2028, 2, 29, 10);
      final c = AgendaAdminController(admin, relogio: relogio);
      expect(c.ultimoDiaCalendario, DateTime(2028, 2, 29 + 365));
      expect(c.primeiroDiaCalendario, DateTime(2028, 2, 29 - 365));
      expect(c.amanha, DateTime(2028, 3, 1));
    });
  });

  group('Agenda Admin: "Hoje"/"Amanhã" depois da meia-noite (S7)', () {
    test('"Hoje" aberto antes da meia-noite: carregar depois dela busca o novo dia', () async {
      final c = AgendaAdminController(admin, relogio: relogio);
      await c.carregar();
      verify(() => admin.listar(DateTime(2030, 1, 15))).called(1);
      agora = DateTime(2030, 1, 16, 0, 5);
      await c.carregar();
      expect(c.periodo, PeriodoAgenda.hoje);
      expect(c.dia, DateTime(2030, 1, 16));
      verify(() => admin.listar(DateTime(2030, 1, 16))).called(1);
    });

    test('"Amanhã" também é recalculado', () async {
      final c = AgendaAdminController(admin, relogio: relogio);
      await c.selecionarAmanha();
      expect(c.dia, DateTime(2030, 1, 16));
      agora = DateTime(2030, 1, 16, 0, 5);
      await c.carregar();
      expect(c.periodo, PeriodoAgenda.amanha);
      expect(c.dia, DateTime(2030, 1, 17));
      verify(() => admin.listar(DateTime(2030, 1, 17))).called(1);
    });

    test('"Data" escolhida NÃO muda com a virada do dia', () async {
      final c = AgendaAdminController(admin, relogio: relogio);
      await c.selecionarData(DateTime(2030, 1, 20));
      agora = DateTime(2030, 1, 16, 0, 5);
      await c.carregar();
      expect(c.periodo, PeriodoAgenda.data);
      expect(c.dia, DateTime(2030, 1, 20));
    });

    test('a lista do dia anterior não fica exibida como se fosse do novo dia', () async {
      when(() => admin.listar(DateTime(2030, 1, 15))).thenAnswer((_) async => [ag(1, DateTime(2030, 1, 15))]);
      final c = AgendaAdminController(admin, relogio: relogio);
      await c.carregar();
      expect(c.total, 1);
      agora = DateTime(2030, 1, 16, 0, 5);
      when(() => admin.listar(DateTime(2030, 1, 16))).thenThrow(Exception('offline'));
      await c.carregar();
      expect(c.dia, DateTime(2030, 1, 16));
      expect(c.total, 0);
      expect(c.erro, isNotNull);
    });
  });

  group('Agenda Admin: widget do calendário "Data"', () {
    Future<AgendaAdminController> abrir(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
      final c = AgendaAdminController(admin, relogio: relogio);
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: c,
        child: MaterialApp(theme: AppTheme.darkTheme, home: const AgendaAdminPage()),
      ));
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('dia mais antigo + meia-noite: o calendário abre com os limites do controller', (tester) async {
      final c = await abrir(tester);
      await c.selecionarData(DateTime(2029, 1, 15));
      await tester.pumpAndSettle();
      agora = DateTime(2030, 1, 16, 8);
      await tester.tap(find.byKey(const Key('periodo-data')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final d = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
      expect(d.firstDate, DateTime(2029, 1, 15));
      expect(d.initialDate, DateTime(2029, 1, 15));
      expect(d.lastDate, DateTime(2031, 1, 16));
    });

    testWidgets('"Hoje" aberto antes da meia-noite: depois de recarregar o título segue "Hoje" no novo dia',
        (tester) async {
      final c = await abrir(tester);
      agora = DateTime(2030, 1, 16, 0, 5);
      await c.carregar();
      await tester.pumpAndSettle();
      expect(find.text('Agenda - Hoje'), findsOneWidget);
      expect(c.dia, DateTime(2030, 1, 16));
    });
  });

  group('Formulário admin: dias selecionáveis na edição', () {
    AgendamentoFormController form(AgendamentoFormArgs args) => AgendamentoFormController(
          adminApi: admin,
          clientesApi: MockClientesApi(),
          agendamentoApi: MockAgendamentoApi(),
          servicosApi: MockServicosApi(),
          args: args,
          relogio: relogio,
        );

    test('edição de um passado: a data original e dias a partir de hoje; passados no meio não', () {
      agora = DateTime(2030, 1, 15, 10);
      final c = form(AgendamentoFormArgs.editar(ag(1, DateTime(2029, 12, 1))));
      expect(c.diaSelecionavel(DateTime(2029, 12, 1)), isTrue);
      expect(c.diaSelecionavel(DateTime(2029, 12, 2)), isFalse);
      expect(c.diaSelecionavel(DateTime(2030, 1, 14)), isFalse);
      expect(c.diaSelecionavel(DateTime(2030, 1, 15)), isTrue);
      expect(c.diaSelecionavel(DateTime(2030, 6, 1)), isTrue);
      // o initialDate do calendário precisa ser selecionável (senão o showDatePicker dispara assert)
      expect(c.diaSelecionavel(c.diaInicialCalendario), isTrue);
    });

    test('edição: a data selecionada continua selecionável mesmo depois da meia-noite', () async {
      agora = DateTime(2030, 1, 15, 23, 50);
      final c = form(AgendamentoFormArgs.editar(ag(1, DateTime(2030, 2, 1))));
      await c.selecionarData(DateTime(2030, 1, 15));
      agora = DateTime(2030, 1, 16, 0, 5);
      expect(c.diaSelecionavel(DateTime(2030, 1, 15)), isTrue);
      expect(c.diaSelecionavel(c.diaInicialCalendario), isTrue);
      expect(c.diaSelecionavel(DateTime(2030, 1, 14)), isFalse);
    });

    test('criação: todos os dias do intervalo valem (o intervalo já começa em hoje)', () {
      agora = DateTime(2030, 1, 15, 10);
      final c = form(AgendamentoFormArgs.criar(data: DateTime(2030, 1, 15)));
      expect(c.diaSelecionavel(DateTime(2030, 1, 15)), isTrue);
      expect(c.diaSelecionavel(DateTime(2030, 3, 1)), isTrue);
    });
  });
}
