// FASE 6 (tester): ação "Exportar CSV", casos que os testes do developer não cobriam.
// - app inteiro (CorteCertoApp + router real): o exportador registrado em lib/app.dart chega à
//   tela de /admin/faturamento (sem isso, em produção todo toque daria SnackBar de erro);
// - exportador que lança de forma síncrona; tela fechada durante a exportação (sem setState
//   depois do dispose); "Tentar novamente" depois do erro volta a habilitar e exporta;
// - navegar durante a exportação: o arquivo é o do período do toque e a ação fica bloqueada até terminar;
// - acessibilidade da ação no harness (360x640, textScaler 2.0): visível, rótulo "Exportar CSV",
//   área de toque >= 48x48 medida na semântica (o androidTapTargetGuideline pula alvos na borda
//   da tela, como as ações da AppBar) e o título "Faturamento" continua na tela.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cortecerto_flutter/app.dart';
import 'package:cortecerto_flutter/core/compartilhamento/exportador_arquivo.dart';
import 'package:cortecerto_flutter/core/router/rotas.dart';
import 'package:cortecerto_flutter/core/session/session_controller.dart';
import 'package:cortecerto_flutter/core/session/usuario.dart';
import 'package:cortecerto_flutter/features/admin/domain/faturamento.dart';
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

final hoje = DateTime(2026, 11, 9, 14, 30);

class Chamada {
  Chamada(this.nomeArquivo, this.bytes, this.mimeType, this.assunto);
  final String nomeArquivo;
  final Uint8List bytes;
  final String mimeType;
  final String assunto;
  String get texto => utf8.decode(bytes.sublist(3));
}

class ExportadorFake extends ExportadorArquivo {
  final chamadas = <Chamada>[];
  Completer<void>? pendente;
  Object? erro;
  bool lancarSincrono = false;

  @override
  Future<void> compartilhar({
    required String nomeArquivo,
    required Uint8List bytes,
    required String mimeType,
    required String assunto,
    Rect? origem,
  }) {
    chamadas.add(Chamada(nomeArquivo, bytes, mimeType, assunto));
    if (lancarSincrono) throw StateError('falha síncrona');
    return () async {
      if (pendente != null) await pendente!.future;
      if (erro != null) throw erro!;
    }();
  }
}

void main() {
  late MockAdminAgendamentoApi api;
  late SessionController admin;
  late ExportadorFake exportador;

  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    registrarFallbacks();
  });

  setUp(() async {
    api = MockAdminAgendamentoApi();
    exportador = ExportadorFake();
    admin = SessionController(FakeTokenStorage());
    await admin.iniciar('t', const Usuario(id: 9, nome: 'Chefe', role: 'ADMIN'));
    when(() => api.faturamento(any(), any())).thenAnswer((i) async =>
        faturamentoFake(i.positionalArguments[0] as DateTime, i.positionalArguments[1] as DateTime));
  });

  final acao = find.byKey(const Key('faturamento-exportar'));
  final snackErro = find.byKey(const Key('snack-erro'));
  bool habilitada(WidgetTester tester) => tester.widget<IconButton>(acao).onPressed != null;

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800 * 3, 4000 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(comRouter(const FaturamentoPage(), providers: [
      ChangeNotifierProvider<SessionController>.value(value: admin),
      Provider<ExportadorArquivo>.value(value: exportador),
      ChangeNotifierProvider(create: (_) => FaturamentoController(api, relogio: () => hoje)),
    ]));
    await tester.pumpAndSettle();
  }

  group('app inteiro (injeção em lib/app.dart)', () {
    testWidgets('ADMIN em /admin/faturamento: o toque usa o exportador de AppDependencies', (tester) async {
      tester.view.physicalSize = const Size(800 * 3, 4000 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final session = SessionController(FakeTokenStorage(criarJwt(role: 'ADMIN')));
      await session.restaurar();
      when(() => api.listar(any())).thenAnswer((_) async => []);
      await tester.pumpWidget(CorteCertoApp(
        deps: AppDependencies(
          session: session,
          authApi: MockAuthApi(),
          servicosApi: MockServicosApi(),
          agendamentoApi: MockAgendamentoApi(),
          adminAgendamentoApi: api,
          clientesApi: MockClientesApi(),
          exportador: exportador,
        ),
        localInicial: Rotas.adminFaturamento,
      ));
      await tester.pumpAndSettle();
      expect(find.byType(FaturamentoPage), findsOneWidget);
      await tester.tap(acao);
      await tester.pumpAndSettle();
      expect(snackErro, findsNothing, reason: 'sem o Provider<ExportadorArquivo> no app a tela mostraria erro');
      expect(exportador.chamadas, hasLength(1));
      final agora = DateTime.now();
      final d = DateTime(agora.year, agora.month, agora.day);
      String dois(int n) => n.toString().padLeft(2, '0');
      expect(exportador.chamadas.single.nomeArquivo, 'faturamento_${d.year}-${dois(d.month)}-${dois(d.day)}.csv');
      expect(exportador.chamadas.single.mimeType, 'text/csv');
    });
  });

  group('robustez do toque', () {
    testWidgets('exportador que lança de forma síncrona: SnackBar de erro e a ação volta', (tester) async {
      await abrir(tester);
      exportador.lancarSincrono = true;
      await tester.tap(acao);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(snackErro, findsOneWidget);
      expect(find.text('Não foi possível exportar o faturamento'), findsOneWidget);
      expect(habilitada(tester), isTrue);
    });

    testWidgets('fechar a folha (termina sem erro): nada de SnackBar e pode exportar de novo', (tester) async {
      await abrir(tester);
      await tester.tap(acao);
      await tester.pumpAndSettle();
      await tester.tap(acao);
      await tester.pumpAndSettle();
      expect(exportador.chamadas, hasLength(2));
      expect(snackErro, findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('tela fechada durante a exportação e depois falha: sem exceção (nada de setState após dispose)',
        (tester) async {
      await abrir(tester);
      exportador.pendente = Completer<void>();
      exportador.erro = Exception('falhou depois');
      await tester.tap(acao);
      await tester.pump();
      expect(exportador.chamadas, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      exportador.pendente!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('navegar durante a exportação: arquivo do período do toque; ação bloqueada até terminar',
        (tester) async {
      await abrir(tester);
      exportador.pendente = Completer<void>();
      await tester.tap(acao);
      await tester.pump();
      await tester.tap(find.byKey(const Key('faturamento-proximo')));
      await tester.pumpAndSettle();
      expect(find.text('10/11/2026'), findsWidgets, reason: 'o período novo já carregou');
      expect(habilitada(tester), isFalse, reason: 'ainda exportando');
      await tester.tap(acao);
      await tester.pump();
      expect(exportador.chamadas, hasLength(1));
      expect(exportador.chamadas.single.nomeArquivo, 'faturamento_2026-11-09.csv');
      expect(exportador.chamadas.single.texto, contains('De;09/11/2026;Até;09/11/2026'));
      exportador.pendente!.complete();
      await tester.pumpAndSettle();
      expect(habilitada(tester), isTrue);
      exportador.pendente = null;
      await tester.tap(acao);
      await tester.pumpAndSettle();
      expect(exportador.chamadas.last.nomeArquivo, 'faturamento_2026-11-10.csv');
    });

    testWidgets('erro na API -> Tentar novamente com sucesso -> habilitada e exporta os dados novos', (tester) async {
      var falhar = true;
      when(() => api.faturamento(any(), any())).thenAnswer((i) async {
        if (falhar) throw Exception('fora do ar');
        return faturamentoFake(i.positionalArguments[0] as DateTime, i.positionalArguments[1] as DateTime);
      });
      await abrir(tester);
      expect(find.byKey(const Key('faturamento-erro')), findsOneWidget);
      expect(habilitada(tester), isFalse);
      await tester.tap(acao);
      await tester.pump();
      expect(exportador.chamadas, isEmpty);
      falhar = false;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(habilitada(tester), isTrue);
      await tester.tap(acao);
      await tester.pumpAndSettle();
      expect(exportador.chamadas, hasLength(1));
      expect(exportador.chamadas.single.texto, contains('Recebido;'));
    });

    testWidgets('resposta atrasada do período anterior não habilita a ação do período novo', (tester) async {
      await abrir(tester);
      final lento10 = Completer<Faturamento>();
      final lento11 = Completer<Faturamento>();
      when(() => api.faturamento(DateTime(2026, 11, 10), any())).thenAnswer((_) => lento10.future);
      when(() => api.faturamento(DateTime(2026, 11, 11), any())).thenAnswer((_) => lento11.future);
      await tester.tap(find.byKey(const Key('faturamento-proximo')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('faturamento-proximo')));
      await tester.pump();
      lento10.complete(faturamentoFake(DateTime(2026, 11, 10), DateTime(2026, 11, 10)));
      await tester.pump();
      await tester.pump();
      expect(habilitada(tester), isFalse, reason: 'na tela está 11/11 carregando; a resposta de 10/11 é descartada');
      lento11.complete(faturamentoFake(DateTime(2026, 11, 11), DateTime(2026, 11, 11)));
      await tester.pumpAndSettle();
      await tester.tap(acao);
      await tester.pumpAndSettle();
      expect(exportador.chamadas.single.nomeArquivo, 'faturamento_2026-11-11.csv');
    });
  });

  group('acessibilidade da ação (harness de a11y)', () {
    for (final estado in [EstadoF4.principal, EstadoF4.mes, EstadoF4.erro]) {
      testWidgets('360x640 textScaler 2.0 / ${estado.name}: ação visível, rotulada, >= 48x48', (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final h = tester.ensureSemantics();
        await abrirTela(tester, TelaF4.faturamento, estado: estado);
        expect(tester.takeException(), isNull);
        expect(acao, findsOneWidget);
        final r = tester.getRect(acao);
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.right, lessThanOrEqualTo(360));
        expect(r.top, greaterThanOrEqualTo(0));
        final sem = tester.getSemantics(acao);
        expect(sem.rect.width, greaterThanOrEqualTo(48));
        expect(sem.rect.height, greaterThanOrEqualTo(48));
        // o leitor de tela anuncia o tooltip do IconButton (label ou tooltip do nó semântico do botão)
        final dados = sem.getSemanticsData();
        expect('${dados.label}|${dados.tooltip}', contains('Exportar CSV'));
        expect(dados.flagsCollection.isButton, isTrue);
        expect(find.descendant(of: find.byType(AppBar), matching: find.text('Faturamento')), findsOneWidget);
        expect(tester.getRect(find.text('Faturamento')).right, lessThanOrEqualTo(r.left + 1),
            reason: 'título não pode ficar por baixo da ação');
        expect(habilitada(tester), estado != EstadoF4.erro);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        h.dispose();
      });
    }
  });
}
