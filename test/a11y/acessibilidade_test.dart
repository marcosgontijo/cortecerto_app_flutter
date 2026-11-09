// FASE 4 (tester), critério 4: guidelines de acessibilidade nas 10 telas, 360x640 com
// textScaler 2.0 sem overflow/exceção, e disableAnimations sem transição.
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'telas_harness.dart';

Future<void> conferirGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

/// Rola todo Scrollable vertical até o fim (constrói os itens de baixo das listas preguiçosas)
/// e volta ao topo, conferindo exceção a cada passo.
Future<void> rolarTudo(WidgetTester tester) async {
  final n = find.byType(Scrollable).evaluate().length;
  for (var i = 0; i < n; i++) {
    final f = find.byType(Scrollable).at(i);
    if (f.evaluate().isEmpty) continue;
    final st = tester.state<ScrollableState>(f);
    if (st.position.axis != Axis.vertical) continue;
    // passos de meia tela para construir os itens no caminho
    while (st.position.pixels < st.position.maxScrollExtent) {
      st.position.jumpTo((st.position.pixels + 300).clamp(0, st.position.maxScrollExtent));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'exceção ao rolar o Scrollable $i');
    }
    st.position.jumpTo(0);
    await tester.pump();
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    registrarFallbacks();
  });

  group('4.1 guidelines (androidTapTarget, labeledTapTarget, textContrast) — estado principal', () {
    for (final tela in TelaF4.values) {
      testWidgets(tela.name, (tester) async {
        final h = tester.ensureSemantics();
        await abrirTela(tester, tela);
        await conferirGuidelines(tester);
        h.dispose();
      });
    }
  });

  group('4.1 guidelines — estados extras', () {
    const extras = <(TelaF4, EstadoF4)>[
      (TelaF4.login, EstadoF4.erro),
      (TelaF4.cadastro, EstadoF4.erro),
      (TelaF4.servicos, EstadoF4.erro),
      (TelaF4.servicos, EstadoF4.vazio),
      (TelaF4.agendamento, EstadoF4.inicial), // sem dia escolhido, botão desabilitado
      (TelaF4.agendamento, EstadoF4.vazio), // API devolve [] (EstadoVazio 'horarios-vazio')
      (TelaF4.meus, EstadoF4.vazio),
      (TelaF4.meus, EstadoF4.erro),
      (TelaF4.agendaAdmin, EstadoF4.detalhes), // bottom sheet aberto
      (TelaF4.agendaAdmin, EstadoF4.erro),
      (TelaF4.formAdmin, EstadoF4.vazio),
      // volta 4: estados novos do Form admin (EstadoErro com retry e EstadoVazio de serviços/horários)
      (TelaF4.formAdmin, EstadoF4.erroServicos),
      (TelaF4.formAdmin, EstadoF4.vazioServicos),
      (TelaF4.formAdmin, EstadoF4.vazioHorarios),
      // volta 5: erro da busca de clientes (EstadoErro com Key form-erro-clientes)
      (TelaF4.formAdmin, EstadoF4.erroClientes),
    ];
    for (final (tela, estado) in extras) {
      testWidgets('${tela.name} / ${estado.name}', (tester) async {
        final h = tester.ensureSemantics();
        await abrirTela(tester, tela, estado: estado);
        await conferirGuidelines(tester);
        h.dispose();
      });
    }
  });

  // Review volta 1 (achado 7): o teste principal do Agendamento só passava porque o calendário
  // tinha rolado para fora da tela (o guideline ignora o que está fora dela). Aqui a rolagem volta
  // a 0 DEPOIS de escolher dia/horário, e o teste confere que o calendário está na tela antes de
  // rodar os guidelines.
  group('4.1c Agendamento com a rolagem no topo (calendário na tela)', () {
    Future<void> rolarParaOTopo(WidgetTester tester) async {
      for (final e in find.byType(Scrollable).evaluate().toList()) {
        final st = (e as StatefulElement).state as ScrollableState;
        if (st.position.axis == Axis.vertical) st.position.jumpTo(0);
      }
      await tester.pumpAndSettle();
    }

    void calendarioNaTela(WidgetTester tester) {
      final tela = Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
      final titulo = tester.getRect(find.text('janeiro de 2030'));
      expect(tela.contains(titulo.topLeft) && tela.contains(titulo.bottomRight), isTrue,
          reason: 'título do mês fora da tela: $titulo');
      final setas = [find.bySemanticsLabel('Mês anterior'), find.bySemanticsLabel('Próximo mês')];
      for (final f in setas) {
        expect(f, findsOneWidget);
        expect(tela.contains(tester.getRect(f).center), isTrue);
      }
      // dia 15 (selecionado) visível
      expect(tela.contains(tester.getRect(find.text('15')).center), isTrue);
    }

    for (final estado in [EstadoF4.principal, EstadoF4.vazio]) {
      testWidgets('agendamento / ${estado.name} / rolagem 0', (tester) async {
        final h = tester.ensureSemantics();
        await abrirTela(tester, TelaF4.agendamento, estado: estado);
        await rolarParaOTopo(tester);
        calendarioNaTela(tester);
        if (estado == EstadoF4.principal) {
          expect(find.byKey(const Key('agendamento-resumo')), findsOneWidget);
        } else {
          expect(find.byKey(const Key('horarios-vazio')), findsOneWidget);
        }
        await conferirGuidelines(tester);
        h.dispose();
      });
    }

    testWidgets('título do mês não tem ação de toque; só as setas trocam o mês', (tester) async {
      final h = tester.ensureSemantics();
      await abrirTela(tester, TelaF4.agendamento, estado: EstadoF4.inicial);
      final titulo = find.text('janeiro de 2030');
      expect(titulo, findsOneWidget);
      final no = tester.getSemantics(titulo);
      final dados = no.getSemanticsData();
      expect(dados.hasAction(SemanticsAction.tap), isFalse, reason: 'título anunciado como botão: $no');
      expect(dados.hasAction(SemanticsAction.longPress), isFalse, reason: '$no');
      // nenhum GestureDetector/InkWell acima do título dentro do cabeçalho do calendário
      expect(
          find.ancestor(
              of: titulo,
              matching: find.byWidgetPredicate((w) =>
                  (w is GestureDetector && (w.onTap != null || w.onLongPress != null)) ||
                  (w is InkWell && (w.onTap != null || w.onLongPress != null)))),
          findsNothing);
      // tocar no título não muda nada
      await tester.tap(titulo);
      await tester.pumpAndSettle();
      expect(find.text('janeiro de 2030'), findsOneWidget);
      // as setas continuam funcionando
      await tester.tap(find.bySemanticsLabel('Próximo mês'));
      await tester.pumpAndSettle();
      expect(find.text('fevereiro de 2030'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Mês anterior'));
      await tester.pumpAndSettle();
      expect(find.text('janeiro de 2030'), findsOneWidget);
      h.dispose();
    });
  });

  // O androidTapTargetGuideline oficial PULA nós que encostam na borda da tela (abas da TabBar de
  // largura total, destinos da NavigationBar no rodapé, ações da AppBar). Medição direta desses alvos:
  group('4.1b alvos na borda da tela (ponto cego do guideline oficial) >= 48x48', () {
    void confere(WidgetTester tester, Finder f, String nome) {
      expect(f, findsWidgets, reason: nome);
      for (final e in f.evaluate()) {
        final r = tester.getSemantics(find.byElementPredicate((x) => x == e)).rect;
        expect(r.width, greaterThanOrEqualTo(48), reason: '$nome largura ${r.size}');
        expect(r.height, greaterThanOrEqualTo(48), reason: '$nome altura ${r.size}');
      }
    }

    for (final tela in [TelaF4.servicos, TelaF4.meus, TelaF4.produtos]) {
      testWidgets('${tela.name}: destinos da NavigationBar, logout e abas', (tester) async {
        final h = tester.ensureSemantics();
        await abrirTela(tester, tela);
        confere(tester, find.byType(NavigationDestination), 'destino');
        confere(tester, find.byKey(const Key('botao-sair')), 'logout');
        if (tela == TelaF4.meus) {
          confere(tester, find.byKey(const Key('aba-proximos')), 'aba Próximos');
          confere(tester, find.byKey(const Key('aba-historico')), 'aba Histórico');
        }
        h.dispose();
      });
    }

    testWidgets('agendaAdmin: FAB', (tester) async {
      final h = tester.ensureSemantics();
      await abrirTela(tester, TelaF4.agendaAdmin);
      confere(tester, find.byKey(const Key('botao-novo-agendamento')), 'FAB');
      h.dispose();
    });
  });

  group('4.2 360x640 com textScaler 2.0, sem overflow nem exceção', () {
    for (final tela in TelaF4.values) {
      testWidgets(tela.name, (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final tipo = await abrirTela(tester, tela);
        expect(tester.takeException(), isNull);
        // o valor chegou na página
        final ctx = tester.element(find.byType(tipo));
        expect(MediaQuery.textScalerOf(ctx).scale(10), 20);
        expect(MediaQuery.sizeOf(ctx), const Size(360, 640));
        await rolarTudo(tester);
        expect(tester.takeException(), isNull);
      });
    }

    for (final (tela, estado) in const <(TelaF4, EstadoF4)>[
      (TelaF4.agendaAdmin, EstadoF4.detalhes),
      (TelaF4.meus, EstadoF4.vazio),
      (TelaF4.servicos, EstadoF4.erro),
      (TelaF4.login, EstadoF4.erro),
      (TelaF4.cadastro, EstadoF4.erro),
      (TelaF4.formAdmin, EstadoF4.vazio),
      (TelaF4.agendamento, EstadoF4.inicial),
      (TelaF4.agendamento, EstadoF4.vazio),
      (TelaF4.formAdmin, EstadoF4.erroServicos),
      (TelaF4.formAdmin, EstadoF4.vazioServicos),
      (TelaF4.formAdmin, EstadoF4.vazioHorarios),
      (TelaF4.formAdmin, EstadoF4.erroClientes),
    ]) {
      testWidgets('${tela.name} / ${estado.name}', (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final tipo = await abrirTela(tester, tela, estado: estado);
        expect(tester.takeException(), isNull);
        final ctx = tester.element(find.byType(tipo));
        expect(MediaQuery.textScalerOf(ctx).scale(10), 20);
        expect(MediaQuery.sizeOf(ctx), const Size(360, 640));
        await rolarTudo(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('4.4 disableAnimations', () {
    /// Opacidade do FadeTransition do AnimatedSwitcher que envolve o resumo.
    double opacidadeResumo(WidgetTester tester) {
      final fade = tester.widget<FadeTransition>(find
          .ancestor(of: find.byKey(const Key('agendamento-resumo')), matching: find.byType(FadeTransition))
          .first);
      return fade.opacity.value;
    }

    Future<void> escolherDiaEHorario(WidgetTester tester) async {
      await abrirTela(tester, TelaF4.agendamento, estado: EstadoF4.inicial);
      await tocarVisivel(tester, find.text('15'));
      await tester.ensureVisible(find.byKey(const Key('horario-08:30')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('horario-08:30')));
      await tester.pump(); // um frame, sem avançar o relógio
    }

    testWidgets('com a flag: o resumo aparece já com opacidade 1 (sem transição)', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await escolherDiaEHorario(tester);
      expect(find.byKey(const Key('agendamento-resumo')), findsOneWidget);
      expect(MediaQuery.disableAnimationsOf(tester.element(find.byKey(const Key('agendamento-resumo')))),
          isTrue);
      expect(opacidadeResumo(tester), 1.0);
      // os AnimatedSwitcher da TELA (resumo e conteúdo de horários), não os internos dos chips
      final daTela = [
        ...tester.widgetList<AnimatedSwitcher>(find.ancestor(
            of: find.byKey(const Key('agendamento-resumo')), matching: find.byType(AnimatedSwitcher))),
        ...tester.widgetList<AnimatedSwitcher>(find.ancestor(
            of: find.byKey(const Key('horario-08:00')), matching: find.byType(AnimatedSwitcher))),
      ];
      expect(daTela, hasLength(2));
      expect(daTela.map((s) => s.duration).toList(), everyElement(Duration.zero));
    });

    testWidgets('controle sem a flag: a transição existe (opacidade < 1 logo após a troca)',
        (tester) async {
      await escolherDiaEHorario(tester);
      expect(opacidadeResumo(tester), lessThan(1.0));
      await tester.pumpAndSettle();
      expect(opacidadeResumo(tester), 1.0);
    });

    testWidgets('com a flag: troca de estado dos horários não deixa o conteúdo antigo na árvore',
        (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await abrirTela(tester, TelaF4.agendamento, estado: EstadoF4.inicial);
      expect(find.byKey(const Key('horarios-escolha-dia')), findsOneWidget);
      await tester.tap(find.text('15'));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('horarios-escolha-dia')), findsNothing);
    });
  });
}
