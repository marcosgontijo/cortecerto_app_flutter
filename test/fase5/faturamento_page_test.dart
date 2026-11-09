// FASE 5 (developer): tela Faturamento com API fake (Dia/Semana/Mês, navegação, resumo, listas,
// estados e refresh) e card Faturamento no Painel.
import 'dart:async';

import 'package:cortecerto_flutter/core/session/session_controller.dart';
import 'package:cortecerto_flutter/core/session/usuario.dart';
import 'package:cortecerto_flutter/core/widgets/estados.dart';
import 'package:cortecerto_flutter/features/admin/domain/faturamento.dart';
import 'package:cortecerto_flutter/features/admin/presentation/admin_page.dart';
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

/// "Hoje" fixo dos testes: 09/11/2026 (segunda-feira).
final hoje = DateTime(2026, 11, 9, 14, 30);

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

  Widget montar() => comRouter(const FaturamentoPage(), providers: [
        ChangeNotifierProvider<SessionController>.value(value: admin),
        ChangeNotifierProvider(create: (_) => FaturamentoController(api, relogio: () => hoje)),
      ]);

  Future<void> abrirGrande(WidgetTester tester) async {
    // tela alta para a lista do mês inteiro caber sem rolar
    tester.view.physicalSize = const Size(800 * 3, 4000 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(montar());
    await tester.pumpAndSettle();
  }

  String rotulo(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('faturamento-periodo'))).data!;

  Future<void> tocar(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  group('abertura e período', () {
    testWidgets('abre em Dia = hoje e busca inicio = fim = hoje', (tester) async {
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();
      expect(find.text('Faturamento'), findsOneWidget);
      final seg = tester.widget<SegmentedButton<Object?>>(find.byKey(const Key('faturamento-tipo')));
      expect(seg.selected.single.toString(), 'TipoPeriodo.dia');
      expect(seg.segments, hasLength(3));
      expect(find.text('Dia'), findsOneWidget);
      expect(find.text('Semana'), findsOneWidget);
      expect(find.text('Mês'), findsOneWidget);
      expect(rotulo(tester), '09/11/2026');
      verify(() => api.faturamento(DateTime(2026, 11, 9), DateTime(2026, 11, 9))).called(1);
    });

    testWidgets('Semana = segunda a domingo; Mês = mês do calendário; volta para Dia', (tester) async {
      await abrirGrande(tester);
      await tocar(tester, find.byKey(const Key('faturamento-tipo-semana')));
      expect(rotulo(tester), '09/11 – 15/11/2026');
      verify(() => api.faturamento(DateTime(2026, 11, 9), DateTime(2026, 11, 15))).called(1);
      await tocar(tester, find.byKey(const Key('faturamento-tipo-mes')));
      expect(rotulo(tester), 'novembro de 2026');
      verify(() => api.faturamento(DateTime(2026, 11, 1), DateTime(2026, 11, 30))).called(1);
      await tocar(tester, find.byKey(const Key('faturamento-tipo-dia')));
      expect(rotulo(tester), '09/11/2026');
      // voltar a um período já visto busca de novo (sem cache)
      verify(() => api.faturamento(DateTime(2026, 11, 9), DateTime(2026, 11, 9))).called(2);
    });

    testWidgets('setas com tooltip: dia ±1, semana ±7, mês ±1 (cada troca busca no servidor)', (tester) async {
      await abrirGrande(tester);
      expect(find.byTooltip('Período anterior'), findsOneWidget);
      expect(find.byTooltip('Próximo período'), findsOneWidget);
      final anterior = find.byKey(const Key('faturamento-anterior'));
      final proximo = find.byKey(const Key('faturamento-proximo'));

      await tocar(tester, anterior);
      expect(rotulo(tester), '08/11/2026');
      verify(() => api.faturamento(DateTime(2026, 11, 8), DateTime(2026, 11, 8))).called(1);
      await tocar(tester, proximo);
      await tocar(tester, proximo);
      expect(rotulo(tester), '10/11/2026');

      // semana que contém 10/11 (seg 09 a dom 15) e as vizinhas
      await tocar(tester, find.byKey(const Key('faturamento-tipo-semana')));
      expect(rotulo(tester), '09/11 – 15/11/2026');
      await tocar(tester, anterior);
      expect(rotulo(tester), '02/11 – 08/11/2026');
      verify(() => api.faturamento(DateTime(2026, 11, 2), DateTime(2026, 11, 8))).called(1);
      await tocar(tester, proximo);
      await tocar(tester, proximo);
      expect(rotulo(tester), '16/11 – 22/11/2026');
      verify(() => api.faturamento(DateTime(2026, 11, 16), DateTime(2026, 11, 22))).called(1);

      // mês: novembro → dezembro → janeiro do ano seguinte
      await tocar(tester, find.byKey(const Key('faturamento-tipo-mes')));
      expect(rotulo(tester), 'novembro de 2026');
      await tocar(tester, proximo);
      expect(rotulo(tester), 'dezembro de 2026');
      await tocar(tester, proximo);
      expect(rotulo(tester), 'janeiro de 2027');
      verify(() => api.faturamento(DateTime(2027, 1, 1), DateTime(2027, 1, 31))).called(1);
      await tocar(tester, anterior);
      await tocar(tester, anterior);
      await tocar(tester, anterior);
      expect(rotulo(tester), 'outubro de 2026');
      verify(() => api.faturamento(DateTime(2026, 10, 1), DateTime(2026, 10, 31))).called(1);
    });

    testWidgets('semana que cruza o ano no rótulo e nos parâmetros', (tester) async {
      tester.view.physicalSize = const Size(800 * 3, 4000 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(comRouter(const FaturamentoPage(), providers: [
        ChangeNotifierProvider<SessionController>.value(value: admin),
        ChangeNotifierProvider(create: (_) => FaturamentoController(api, relogio: () => DateTime(2025, 12, 31))),
      ]));
      await tester.pumpAndSettle();
      await tocar(tester, find.byKey(const Key('faturamento-tipo-semana')));
      expect(rotulo(tester), '29/12/2025 – 04/01/2026');
      verify(() => api.faturamento(DateTime(2025, 12, 29), DateTime(2026, 1, 4))).called(1);
    });
  });

  group('resumo e listas', () {
    testWidgets('Recebido em destaque e Previsto à parte, com quantidades e R\$ pt-BR', (tester) async {
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();
      final recebido = find.byKey(const Key('faturamento-recebido'));
      final previsto = find.byKey(const Key('faturamento-previsto'));
      expect(recebido, findsOneWidget);
      expect(previsto, findsOneWidget);
      expect(find.descendant(of: recebido, matching: find.text(r'R$ 1.234,50')), findsOneWidget);
      expect(find.descendant(of: recebido, matching: find.text('30 atendimentos realizados')), findsOneWidget);
      expect(find.descendant(of: previsto, matching: find.text(r'R$ 55,00')), findsOneWidget);
      expect(find.descendant(of: previsto, matching: find.text('1 atendimento confirmado ou pendente')),
          findsOneWidget);
      final grande = tester.widget<Text>(find.byKey(const Key('faturamento-recebido-valor'))).style!.fontSize!;
      final menor = tester.widget<Text>(find.byKey(const Key('faturamento-previsto-valor'))).style!.fontSize!;
      expect(grande, greaterThan(menor));
    });

    testWidgets('Dia: sem lista por dia; lista por serviço na ordem da API', (tester) async {
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('faturamento-por-dia')), findsNothing);
      await tester.scrollUntilVisible(find.byKey(const Key('faturamento-servico-1')), 200);
      expect(find.descendant(of: find.byKey(const Key('faturamento-servico-0')), matching: find.text('Corte + Barba')),
          findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('faturamento-servico-0')), matching: find.text(r'R$ 1.100,00')),
          findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('faturamento-servico-1')), matching: find.text('Corte Simples')),
          findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('faturamento-servico-1')), matching: find.text(r'R$ 169,50')),
          findsOneWidget);
      expect(tester.getTopLeft(find.byKey(const Key('faturamento-servico-0'))).dy,
          lessThan(tester.getTopLeft(find.byKey(const Key('faturamento-servico-1'))).dy));
    });

    testWidgets('Semana: 7 dias com valor em texto e barra proporcional (zero = sem barra)', (tester) async {
      await abrirGrande(tester);
      await tocar(tester, find.byKey(const Key('faturamento-tipo-semana')));
      expect(find.byKey(const Key('faturamento-por-dia')), findsOneWidget);
      for (var d = 9; d <= 15; d++) {
        expect(find.byKey(Key('faturamento-dia-2026-11-${'$d'.padLeft(2, '0')}')), findsOneWidget, reason: '$d/11');
      }
      expect(find.byKey(const Key('faturamento-dia-2026-11-08')), findsNothing);
      expect(find.byKey(const Key('faturamento-dia-2026-11-16')), findsNothing);
      // valores em texto (a informação não depende só da barra)
      expect(tester.widget<Text>(find.byKey(const Key('faturamento-dia-valor-2026-11-09'))).data, r'R$ 1.234,50');
      expect(tester.widget<Text>(find.byKey(const Key('faturamento-dia-valor-2026-11-10'))).data, r'R$ 35,00');
      expect(tester.widget<Text>(find.byKey(const Key('faturamento-dia-valor-2026-11-11'))).data, r'R$ 0,00');
      // barra: o maior ocupa a trilha inteira; o outro é proporcional; zero não tem barra
      final maior = tester.getSize(find.byKey(const Key('faturamento-barra-2026-11-09')));
      final menor = tester.getSize(find.byKey(const Key('faturamento-barra-2026-11-10')));
      final trilha = tester.getSize(find.ancestor(
          of: find.byKey(const Key('faturamento-barra-2026-11-09')), matching: find.byType(Container)).first);
      expect(maior.width, closeTo(trilha.width, 0.01));
      expect(menor.width / maior.width, closeTo(3500 / 123450, 0.001));
      expect(find.byKey(const Key('faturamento-barra-2026-11-11')), findsNothing);
      // a barra fica fora da semântica, o valor fica dentro
      expect(find.ancestor(of: find.byKey(const Key('faturamento-barra-2026-11-09')), matching: find.byType(ExcludeSemantics)),
          findsWidgets);
      expect(find.byKey(const Key('faturamento-por-servico')), findsOneWidget);
    });

    testWidgets('Mês: uma linha por dia do mês (30 em novembro)', (tester) async {
      await abrirGrande(tester);
      await tocar(tester, find.byKey(const Key('faturamento-tipo-mes')));
      final linhas = find.byWidgetPredicate(
          (w) => w.key is ValueKey<String> && RegExp(r'^faturamento-dia-\d{4}-').hasMatch((w.key as ValueKey<String>).value));
      expect(linhas, findsNWidgets(30));
      expect(find.byKey(const Key('faturamento-dia-2026-11-01')), findsOneWidget);
      expect(find.byKey(const Key('faturamento-dia-2026-11-30')), findsOneWidget);
    });
  });

  group('estados', () {
    testWidgets('carregando: EstadoCarregando enquanto a API não responde', (tester) async {
      final c = Completer<Faturamento>();
      when(() => api.faturamento(any(), any())).thenAnswer((_) => c.future);
      await tester.pumpWidget(montar());
      await tester.pump();
      expect(find.byKey(const Key('faturamento-carregando')), findsOneWidget);
      expect(find.byType(EstadoCarregando), findsOneWidget);
      expect(find.byKey(const Key('faturamento-recebido')), findsNothing);
      c.complete(faturamentoFake(DateTime(2026, 11, 9), DateTime(2026, 11, 9)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('faturamento-carregando')), findsNothing);
      expect(find.byKey(const Key('faturamento-recebido')), findsOneWidget);
    });

    testWidgets('vazio: mensagem no lugar das listas e o resumo continua (Previsto visível)', (tester) async {
      when(() => api.faturamento(any(), any())).thenAnswer((i) async => faturamentoFake(
          i.positionalArguments[0] as DateTime, i.positionalArguments[1] as DateTime,
          vazio: true));
      await abrirGrande(tester);
      expect(find.text('Nenhum atendimento realizado neste período'), findsOneWidget);
      expect(find.byType(EstadoVazio), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('faturamento-recebido')), matching: find.text(r'R$ 0,00')),
          findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('faturamento-previsto')), matching: find.text(r'R$ 55,00')),
          findsOneWidget);
      expect(find.byKey(const Key('faturamento-por-servico')), findsNothing);
      await tocar(tester, find.byKey(const Key('faturamento-tipo-semana')));
      expect(find.byKey(const Key('faturamento-por-dia')), findsNothing);
      expect(find.text('Nenhum atendimento realizado neste período'), findsOneWidget);
    });

    testWidgets('erro: EstadoErro com "Tentar novamente" que chama a API de novo', (tester) async {
      var falhar = true;
      when(() => api.faturamento(any(), any())).thenAnswer((i) async {
        if (falhar) throw semConexao;
        return faturamentoFake(i.positionalArguments[0] as DateTime, i.positionalArguments[1] as DateTime);
      });
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('faturamento-erro')), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(find.byKey(const Key('faturamento-recebido')), findsNothing);
      falhar = false;
      await tocar(tester, find.text('Tentar novamente'));
      verify(() => api.faturamento(DateTime(2026, 11, 9), DateTime(2026, 11, 9))).called(2);
      expect(find.byKey(const Key('faturamento-erro')), findsNothing);
      expect(find.byKey(const Key('faturamento-recebido')), findsOneWidget);
    });

    testWidgets('pull-to-refresh busca de novo no servidor (nos dados e no erro)', (tester) async {
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();
      verify(() => api.faturamento(any(), any())).called(1);
      await tester.fling(find.byKey(const Key('faturamento-tipo')), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      verify(() => api.faturamento(DateTime(2026, 11, 9), DateTime(2026, 11, 9))).called(1);

      when(() => api.faturamento(any(), any())).thenThrow(semConexao);
      await tester.fling(find.byKey(const Key('faturamento-tipo')), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('faturamento-erro')), findsOneWidget);
      await tester.fling(find.byKey(const Key('faturamento-erro')), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      verify(() => api.faturamento(any(), any())).called(2);
    });

    testWidgets('resposta de um período antigo não sobrescreve o período atual', (tester) async {
      final lento = Completer<Faturamento>();
      when(() => api.faturamento(DateTime(2026, 11, 9), DateTime(2026, 11, 9))).thenAnswer((_) => lento.future);
      when(() => api.faturamento(DateTime(2026, 11, 10), DateTime(2026, 11, 10)))
          .thenAnswer((_) async => faturamentoFake(DateTime(2026, 11, 10), DateTime(2026, 11, 10), vazio: true));
      await tester.pumpWidget(montar());
      await tester.pump();
      await tester.tap(find.byKey(const Key('faturamento-proximo')));
      await tester.pumpAndSettle();
      expect(rotulo(tester), '10/11/2026');
      expect(find.text('Nenhum atendimento realizado neste período'), findsOneWidget);
      lento.complete(faturamentoFake(DateTime(2026, 11, 9), DateTime(2026, 11, 9)));
      await tester.pumpAndSettle();
      expect(find.text('Nenhum atendimento realizado neste período'), findsOneWidget);
      expect(find.text(r'R$ 1.234,50'), findsNothing);
    });
  });

  group('Painel Admin', () {
    testWidgets('card Faturamento (ícone >= 32 + texto, altura >= 72) leva a /admin/faturamento', (tester) async {
      await tester.pumpWidget(comRouter(const AdminPage(), providers: [
        ChangeNotifierProvider<SessionController>.value(value: admin),
      ]));
      final card = find.byKey(const Key('card-faturamento'));
      expect(card, findsOneWidget);
      expect(tester.getSize(card).height, greaterThanOrEqualTo(72));
      final icone = tester.widget<Icon>(find.descendant(of: card, matching: find.byIcon(Icons.payments_outlined)));
      expect(icone.size, greaterThanOrEqualTo(32));
      expect(find.descendant(of: card, matching: find.text('Faturamento')), findsOneWidget);
      // mesmo padrão do card Agenda (altura mínima 96, chevron) e logo abaixo dele
      expect(tester.getSize(card).height, greaterThanOrEqualTo(96));
      expect(find.descendant(of: card, matching: find.byIcon(Icons.chevron_right)), findsOneWidget);
      expect(tester.getTopLeft(card).dy, greaterThan(tester.getTopLeft(find.byKey(const Key('card-agenda'))).dy));
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text('TELA faturamento'), findsOneWidget);
    });
  });
}
