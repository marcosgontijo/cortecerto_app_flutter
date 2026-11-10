// FASE 6 (developer): ação "Exportar CSV" da tela Faturamento com API e exportador fakes:
// habilitação (carregando, erro, refresh, vazio), exporta o período exibido (inclusive depois
// de navegar), sem nova requisição, sem toque duplo, SnackBar no erro e fechar a folha não é erro.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cortecerto_flutter/app.dart';
import 'package:cortecerto_flutter/core/compartilhamento/exportador_arquivo.dart';
import 'package:cortecerto_flutter/core/compartilhamento/exportador_share_plus.dart';
import 'package:cortecerto_flutter/core/session/session_controller.dart';
import 'package:cortecerto_flutter/core/session/usuario.dart';
import 'package:cortecerto_flutter/features/admin/domain/faturamento.dart';
import 'package:cortecerto_flutter/features/admin/domain/faturamento_csv.dart';
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

/// "Hoje" fixo dos testes: 09/11/2026 (segunda-feira).
final hoje = DateTime(2026, 11, 9, 14, 30);

class Chamada {
  Chamada(this.nomeArquivo, this.bytes, this.mimeType, this.assunto, this.origem);
  final String nomeArquivo;
  final Uint8List bytes;
  final String mimeType;
  final String assunto;
  final Rect? origem;

  String get texto => utf8.decode(bytes.sublist(3));
}

/// Exportador fake: grava as chamadas; [pendente] segura a conclusão; [erro] faz lançar.
class ExportadorFake extends ExportadorArquivo {
  final chamadas = <Chamada>[];
  Completer<void>? pendente;
  Object? erro;

  @override
  Future<void> compartilhar({
    required String nomeArquivo,
    required Uint8List bytes,
    required String mimeType,
    required String assunto,
    Rect? origem,
  }) async {
    chamadas.add(Chamada(nomeArquivo, bytes, mimeType, assunto, origem));
    if (pendente != null) await pendente!.future;
    if (erro != null) throw erro!;
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

  Widget montar() => comRouter(const FaturamentoPage(), providers: [
        ChangeNotifierProvider<SessionController>.value(value: admin),
        Provider<ExportadorArquivo>.value(value: exportador),
        ChangeNotifierProvider(create: (_) => FaturamentoController(api, relogio: () => hoje)),
      ]);

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800 * 3, 4000 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(montar());
    await tester.pumpAndSettle();
  }

  final acao = find.byKey(const Key('faturamento-exportar'));
  bool habilitada(WidgetTester tester) => tester.widget<IconButton>(acao).onPressed != null;
  FaturamentoController controller(WidgetTester tester) =>
      tester.element(find.byType(FaturamentoPage)).read<FaturamentoController>();

  Future<void> tocar(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('ação visível com tooltip, ícone e área de toque ≥ 48dp', (tester) async {
    await abrir(tester);
    expect(find.byTooltip('Exportar CSV'), findsOneWidget);
    expect(find.descendant(of: acao, matching: find.byIcon(Icons.file_download_outlined)), findsOneWidget);
    final tamanho = tester.getSize(acao);
    expect(tamanho.width, greaterThanOrEqualTo(48));
    expect(tamanho.height, greaterThanOrEqualTo(48));
    expect(habilitada(tester), isTrue);
  });

  testWidgets('desabilitada enquanto carrega o primeiro período', (tester) async {
    final c = Completer<Faturamento>();
    when(() => api.faturamento(any(), any())).thenAnswer((_) => c.future);
    await tester.pumpWidget(montar());
    await tester.pump();
    expect(find.byKey(const Key('faturamento-carregando')), findsOneWidget);
    expect(habilitada(tester), isFalse);
    c.complete(faturamentoFake(DateTime(2026, 11, 9), DateTime(2026, 11, 9)));
    await tester.pumpAndSettle();
    expect(habilitada(tester), isTrue);
  });

  testWidgets('desabilitada no erro', (tester) async {
    when(() => api.faturamento(any(), any())).thenThrow(Exception('falhou'));
    await abrir(tester);
    expect(find.byKey(const Key('faturamento-erro')), findsOneWidget);
    expect(habilitada(tester), isFalse);
  });

  testWidgets('desabilitada no refresh do mesmo período e no erro do refresh (dados antigos)', (tester) async {
    await abrir(tester);
    expect(habilitada(tester), isTrue);
    final lento = Completer<Faturamento>();
    when(() => api.faturamento(any(), any())).thenAnswer((_) => lento.future);
    unawaited(controller(tester).carregar());
    await tester.pump();
    expect(controller(tester).faturamento, isNotNull, reason: 'refresh mantém os dados antigos');
    expect(habilitada(tester), isFalse);
    lento.completeError(Exception('caiu'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('faturamento-erro')), findsOneWidget);
    expect(controller(tester).faturamento, isNotNull);
    expect(habilitada(tester), isFalse);
  });

  testWidgets('habilitada no estado vazio (sem realizados)', (tester) async {
    when(() => api.faturamento(any(), any())).thenAnswer((i) async => faturamentoFake(
        i.positionalArguments[0] as DateTime, i.positionalArguments[1] as DateTime,
        vazio: true));
    await abrir(tester);
    expect(find.byKey(const Key('faturamento-vazio')), findsOneWidget);
    expect(habilitada(tester), isTrue);
    await tocar(tester, acao);
    expect(exportador.chamadas, hasLength(1));
    expect(exportador.chamadas.single.texto, contains('Nenhum atendimento realizado neste período'));
  });

  testWidgets('toque exporta o período exibido (nome, BOM, texto, mime, assunto) sem nova requisição',
      (tester) async {
    await abrir(tester);
    verify(() => api.faturamento(DateTime(2026, 11, 9), DateTime(2026, 11, 9))).called(1);
    await tocar(tester, acao);
    verifyNever(() => api.faturamento(any(), any()));
    expect(exportador.chamadas, hasLength(1));
    final ch = exportador.chamadas.single;
    final esperado = FaturamentoCsv(faturamentoFake(DateTime(2026, 11, 9), DateTime(2026, 11, 9)),
        PeriodoFaturamento.contendo(TipoPeriodo.dia, hoje));
    expect(ch.nomeArquivo, 'faturamento_2026-11-09.csv');
    expect(ch.bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    expect(ch.bytes, esperado.bytes);
    expect(ch.texto, esperado.texto);
    expect(ch.mimeType, 'text/csv');
    expect(ch.assunto, contains('09/11/2026'));
    expect(ch.origem, isNotNull);
    expect(find.byKey(const Key('snack-erro')), findsNothing);
  });

  testWidgets('depois de navegar exporta o novo período (próximo dia, semana e mês)', (tester) async {
    await abrir(tester);
    await tocar(tester, find.byKey(const Key('faturamento-proximo')));
    await tocar(tester, acao);
    expect(exportador.chamadas.last.nomeArquivo, 'faturamento_2026-11-10.csv');
    expect(exportador.chamadas.last.texto, contains('De;10/11/2026;Até;10/11/2026'));

    await tocar(tester, find.byKey(const Key('faturamento-anterior')));
    await tocar(tester, find.byKey(const Key('faturamento-tipo-semana')));
    clearInteractions(api);
    await tocar(tester, acao);
    verifyNever(() => api.faturamento(any(), any()));
    expect(exportador.chamadas.last.nomeArquivo, 'faturamento_2026-11-09_a_2026-11-15.csv');
    expect(exportador.chamadas.last.texto, contains('Período;09/11 – 15/11/2026\r\nDe;09/11/2026;Até;15/11/2026'));
    expect(exportador.chamadas.last.assunto, contains('09/11 – 15/11/2026'));

    await tocar(tester, find.byKey(const Key('faturamento-tipo-mes')));
    await tocar(tester, acao);
    expect(exportador.chamadas.last.nomeArquivo, 'faturamento_2026-11.csv');
    expect(exportador.chamadas.last.texto, contains('De;01/11/2026;Até;30/11/2026'));
    expect(exportador.chamadas, hasLength(3));
  });

  testWidgets('período mudou e ainda carrega: desabilitada (não exporta o período anterior)', (tester) async {
    await abrir(tester);
    final lento = Completer<Faturamento>();
    when(() => api.faturamento(any(), any())).thenAnswer((_) => lento.future);
    await tester.tap(find.byKey(const Key('faturamento-proximo')));
    await tester.pump();
    expect(habilitada(tester), isFalse);
    await tester.tap(acao);
    await tester.pump();
    expect(exportador.chamadas, isEmpty);
    lento.complete(faturamentoFake(DateTime(2026, 11, 10), DateTime(2026, 11, 10)));
    await tester.pumpAndSettle();
    expect(habilitada(tester), isTrue);
  });

  testWidgets('sem toque duplo: desabilitada enquanto prepara e volta ao terminar', (tester) async {
    await abrir(tester);
    exportador.pendente = Completer<void>();
    await tester.tap(acao);
    await tester.pump();
    expect(habilitada(tester), isFalse);
    await tester.tap(acao);
    await tester.pump();
    expect(exportador.chamadas, hasLength(1));
    exportador.pendente!.complete();
    await tester.pumpAndSettle();
    expect(habilitada(tester), isTrue);
    expect(find.byKey(const Key('snack-erro')), findsNothing);
  });

  testWidgets('erro ao compartilhar: SnackBar clara e a ação volta a habilitar', (tester) async {
    await abrir(tester);
    exportador.erro = Exception('sem app para compartilhar');
    await tocar(tester, acao);
    expect(find.byKey(const Key('snack-erro')), findsOneWidget);
    expect(find.text('Não foi possível exportar o faturamento'), findsOneWidget);
    expect(habilitada(tester), isTrue);
  });

  testWidgets('sem exportador registrado: SnackBar de erro em vez de quebrar a tela', (tester) async {
    tester.view.physicalSize = const Size(800 * 3, 4000 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(comRouter(const FaturamentoPage(), providers: [
      ChangeNotifierProvider<SessionController>.value(value: admin),
      ChangeNotifierProvider(create: (_) => FaturamentoController(api, relogio: () => hoje)),
    ]));
    await tester.pumpAndSettle();
    await tocar(tester, acao);
    expect(find.text('Não foi possível exportar o faturamento'), findsOneWidget);
  });

  test('AppDependencies usa o exportador real (share_plus) por padrão e aceita um fake', () {
    final deps = AppDependencies.criar();
    expect(deps.exportador, isA<ExportadorSharePlus>());
    final fake = ExportadorFake();
    final comFake = AppDependencies(
      session: deps.session,
      authApi: deps.authApi,
      servicosApi: deps.servicosApi,
      agendamentoApi: deps.agendamentoApi,
      adminAgendamentoApi: deps.adminAgendamentoApi,
      clientesApi: deps.clientesApi,
      exportador: fake,
    );
    expect(comFake.exportador, same(fake));
  });
}
