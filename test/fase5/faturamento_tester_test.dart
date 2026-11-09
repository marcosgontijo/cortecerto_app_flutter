// FASE 5 (tester, volta 1): casos de borda do Faturamento que os testes do developer não cobrem.
// - Semana a partir de um DOMINGO e de uma quarta no controller (o domingo é onde a semana
//   "começando no domingo" ou weekday % 7 erra).
// - Mês: navegação a partir de 31/01 (fevereiro com 28 dias, depois março inteiro) e ano bissexto.
// - Valores exibidos vêm da API (recebido/previsto) e a barra é proporcional ao maior dia também no Mês.
// - Rótulos de quantidade no singular/plural e R$ 0,00 no Previsto zerado.
import 'dart:async';

import 'package:cortecerto_flutter/core/session/session_controller.dart';
import 'package:cortecerto_flutter/core/session/usuario.dart';
import 'package:cortecerto_flutter/features/admin/domain/faturamento.dart';
import 'package:cortecerto_flutter/features/admin/domain/periodo_faturamento.dart';
import 'package:cortecerto_flutter/features/admin/presentation/faturamento_controller.dart';
import 'package:cortecerto_flutter/features/admin/presentation/faturamento_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../a11y/telas_harness.dart';
import '../helpers/fakes.dart';
import '../helpers/widget_helpers.dart';

void main() {
  late MockAdminAgendamentoApi api;
  late SessionController admin;

  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    registrarFallbacks();
  });

  setUp(() async {
    api = MockAdminAgendamentoApi();
    admin = SessionController(FakeTokenStorage());
    await admin.iniciar('t', const Usuario(id: 9, nome: 'Chefe', role: 'ADMIN'));
    when(() => api.faturamento(any(), any())).thenAnswer((i) async =>
        faturamentoFake(i.positionalArguments[0] as DateTime, i.positionalArguments[1] as DateTime));
  });

  group('controller (sem tela)', () {
    // O teste do developer ("resposta de um período antigo...") olha só a tela: se o controller
    // GRAVAR a resposta antiga sem notificar, a tela não reconstrói e o teste passa por acaso
    // (mutação F11 sobreviveu). Aqui o estado do controller é conferido diretamente.
    test('resposta atrasada de um período antigo não substitui o estado do período atual', () async {
      final lento = Completer<Faturamento>();
      when(() => api.faturamento(DateTime(2026, 11, 9), DateTime(2026, 11, 9))).thenAnswer((_) => lento.future);
      final c = FaturamentoController(api, relogio: () => DateTime(2026, 11, 9));
      final primeira = c.carregar();
      await c.proximo();
      expect(c.faturamento!.inicio, DateTime(2026, 11, 10));
      lento.complete(faturamentoFake(DateTime(2026, 11, 9), DateTime(2026, 11, 9)));
      await primeira;
      expect(c.periodo.inicio, DateTime(2026, 11, 10));
      expect(c.faturamento!.inicio, DateTime(2026, 11, 10), reason: 'resposta do dia 09 gravada por cima do dia 10');
      expect(c.isLoading, isFalse);
    });

    test('erro atrasado de um período antigo não vira erro do período atual', () async {
      final lento = Completer<Faturamento>();
      when(() => api.faturamento(DateTime(2026, 11, 9), DateTime(2026, 11, 9))).thenAnswer((_) => lento.future);
      final c = FaturamentoController(api, relogio: () => DateTime(2026, 11, 9));
      final primeira = c.carregar();
      await c.proximo();
      lento.completeError(semConexao);
      await primeira;
      expect(c.erro, isNull);
      expect(c.faturamento!.inicio, DateTime(2026, 11, 10));
    });

    test('hoje = DOMINGO 15/11/2026: Semana = segunda 09/11 a domingo 15/11', () async {
      final c = FaturamentoController(api, relogio: () => DateTime(2026, 11, 15, 23, 50));
      await c.carregar();
      verify(() => api.faturamento(DateTime(2026, 11, 15), DateTime(2026, 11, 15))).called(1);
      await c.selecionarTipo(TipoPeriodo.semana);
      verify(() => api.faturamento(DateTime(2026, 11, 9), DateTime(2026, 11, 15))).called(1);
      expect(c.periodo.rotulo, '09/11 – 15/11/2026');
    });

    test('hoje = quarta 11/11/2026: Semana 09/11..15/11; anterior 02/11..08/11', () async {
      final c = FaturamentoController(api, relogio: () => DateTime(2026, 11, 11, 8));
      await c.selecionarTipo(TipoPeriodo.semana);
      verify(() => api.faturamento(DateTime(2026, 11, 9), DateTime(2026, 11, 15))).called(1);
      await c.anterior();
      verify(() => api.faturamento(DateTime(2026, 11, 2), DateTime(2026, 11, 8))).called(1);
    });

    test('Mês a partir de 31/01/2027: próximo = fevereiro 01..28, depois março 01..31', () async {
      final c = FaturamentoController(api, relogio: () => DateTime(2027, 1, 31));
      await c.selecionarTipo(TipoPeriodo.mes);
      verify(() => api.faturamento(DateTime(2027, 1, 1), DateTime(2027, 1, 31))).called(1);
      await c.proximo();
      verify(() => api.faturamento(DateTime(2027, 2, 1), DateTime(2027, 2, 28))).called(1);
      await c.proximo();
      verify(() => api.faturamento(DateTime(2027, 3, 1), DateTime(2027, 3, 31))).called(1);
      expect(c.periodo.rotulo, 'março de 2027');
    });

    test('Mês bissexto: fevereiro de 2028 = 01..29', () async {
      final c = FaturamentoController(api, relogio: () => DateTime(2028, 2, 10));
      await c.selecionarTipo(TipoPeriodo.mes);
      verify(() => api.faturamento(DateTime(2028, 2, 1), DateTime(2028, 2, 29))).called(1);
    });

    test('Dia: anterior/próximo atravessam o ano (31/12 → 01/01)', () async {
      final c = FaturamentoController(api, relogio: () => DateTime(2026, 12, 31));
      await c.proximo();
      verify(() => api.faturamento(DateTime(2027, 1, 1), DateTime(2027, 1, 1))).called(1);
      await c.anterior();
      await c.anterior();
      verify(() => api.faturamento(DateTime(2026, 12, 30), DateTime(2026, 12, 30))).called(1);
    });
  });

  group('tela', () {
    Future<void> abrir(WidgetTester tester, {DateTime? hoje}) async {
      tester.view.physicalSize = const Size(800 * 3, 4000 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(comRouter(const FaturamentoPage(), providers: [
        ChangeNotifierProvider<SessionController>.value(value: admin),
        ChangeNotifierProvider(
            create: (_) => FaturamentoController(api, relogio: () => hoje ?? DateTime(2026, 11, 9, 14))),
      ]));
      await tester.pumpAndSettle();
    }

    testWidgets('resumo mostra recebido/previsto DA API (não soma local) e pluraliza as quantidades',
        (tester) async {
      when(() => api.faturamento(any(), any())).thenAnswer((i) async => Faturamento(
            inicio: i.positionalArguments[0] as DateTime,
            fim: i.positionalArguments[1] as DateTime,
            recebidoCentavos: 4000,
            previstoCentavos: 0,
            quantidadeRealizados: 1,
            quantidadePrevistos: 0,
            porServico: const [FaturamentoServico(servico: 'Corte', quantidade: 1, recebidoCentavos: 4000)],
          ));
      await abrir(tester);
      final recebido = find.byKey(const Key('faturamento-recebido'));
      final previsto = find.byKey(const Key('faturamento-previsto'));
      expect(find.descendant(of: recebido, matching: find.text(r'R$ 40,00')), findsOneWidget);
      expect(find.descendant(of: recebido, matching: find.text('1 atendimento realizado')), findsOneWidget);
      expect(find.descendant(of: previsto, matching: find.text(r'R$ 0,00')), findsOneWidget);
      expect(find.descendant(of: previsto, matching: find.textContaining('0 atendimentos')), findsOneWidget);
    });

    testWidgets('Mês: barra proporcional ao maior dia e dia zerado sem barra (e com valor em texto)',
        (tester) async {
      await abrir(tester);
      await tester.tap(find.byKey(const Key('faturamento-tipo-mes')));
      await tester.pumpAndSettle();
      // faturamentoFake: 01/11 = 1234,50; 02/11 = 35,00; resto 0
      final b1 = tester.getSize(find.byKey(const Key('faturamento-barra-2026-11-01')));
      final b2 = tester.getSize(find.byKey(const Key('faturamento-barra-2026-11-02')));
      expect(b2.width / b1.width, closeTo(3500 / 123450, 0.001));
      expect(find.byKey(const Key('faturamento-barra-2026-11-03')), findsNothing);
      expect(tester.widget<Text>(find.byKey(const Key('faturamento-dia-valor-2026-11-30'))).data, r'R$ 0,00');
    });

    testWidgets('domingo: o seletor Semana mostra 09/11 – 15/11/2026 (não começa no domingo)', (tester) async {
      await abrir(tester, hoje: DateTime(2026, 11, 15, 10));
      await tester.tap(find.byKey(const Key('faturamento-tipo-semana')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('faturamento-periodo'))).data, '09/11 – 15/11/2026');
      for (var d = 9; d <= 15; d++) {
        expect(find.byKey(Key('faturamento-dia-2026-11-${'$d'.padLeft(2, '0')}')), findsOneWidget, reason: '$d/11');
      }
      expect(find.byKey(const Key('faturamento-dia-2026-11-16')), findsNothing);
    });
  });
}
