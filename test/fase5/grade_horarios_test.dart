// FASE 5 (developer): grade de horários do Agendamento com colunas de largura igual que preenchem
// a largura disponível (360 e 800 dp), menos colunas com texto grande, e a FASE 4 preservada.
import 'dart:io';

import 'package:cortecerto_flutter/core/session/session_controller.dart';
import 'package:cortecerto_flutter/core/session/usuario.dart';
import 'package:cortecerto_flutter/core/theme/app_theme.dart';
import 'package:cortecerto_flutter/features/agendamento/presentation/agendamento_controller.dart';
import 'package:cortecerto_flutter/features/agendamento/presentation/agendamento_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../a11y/telas_harness.dart';
import '../helpers/fakes.dart';
import '../helpers/widget_helpers.dart';

/// Carrega a Roboto do SDK do Flutter (a fonte padrão do Android) para medir a grade com a
/// fonte real, e não só com a fonte de teste (glifos quadrados, bem mais largos).
Future<void> carregarRoboto() async {
  final raiz = Platform.environment['FLUTTER_ROOT'];
  expect(raiz, isNotNull, reason: 'FLUTTER_ROOT não definido pelo flutter test');
  final dir = '$raiz/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  for (final f in ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf']) {
    final arquivo = File('$dir/$f');
    expect(arquivo.existsSync(), isTrue, reason: '${arquivo.path} não encontrado');
    loader.addFont(arquivo.readAsBytes().then((b) => ByteData.view(Uint8List.fromList(b).buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    registrarFallbacks();
    await carregarRoboto();
  });

  /// Monta o Agendamento (hoje = 10/01/2030), escolhe o dia 15 (3 livres, 21 indisponíveis).
  Future<void> abrir(WidgetTester tester, double largura, {double escala = 1.0, bool roboto = false}) async {
    tester.view.physicalSize = Size(largura * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.textScaleFactorTestValue = escala;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final api = MockAgendamentoApi();
    when(() => api.disponibilidades(any())).thenAnswer((_) async => ['08:00', '08:30', '10:00']);
    final s = SessionController(FakeTokenStorage());
    await s.iniciar('t', const Usuario(id: 3, nome: 'Maria', role: 'CLIENTE'));
    final pagina = AgendamentoPage(servico: servicoTeste, hoje: DateTime(2030, 1, 10));
    final providers = [
      ChangeNotifierProvider<SessionController>.value(value: s),
      ChangeNotifierProvider(create: (_) => AgendamentoController(api)),
    ];
    if (roboto) {
      final base = AppTheme.darkTheme;
      final tema = base.copyWith(textTheme: base.textTheme.apply(fontFamily: 'Roboto'));
      await tester.pumpWidget(MultiProvider(
        providers: providers,
        child: MaterialApp.router(
          theme: tema,
          routerConfig: GoRouter(routes: [GoRoute(path: '/', builder: (_, _) => pagina)]),
        ),
      ));
    } else {
      await tester.pumpWidget(comRouter(pagina, providers: providers));
    }
    await tester.pumpAndSettle();
    await tocarVisivel(tester, find.text('15'));
    expect(tester.takeException(), isNull);
  }

  Finder chips() => find.byWidgetPredicate((w) =>
      w is ChoiceChip && w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('horario-'));

  /// Linhas da grade (retângulos dos chips agrupados pelo topo, em ordem).
  List<List<Rect>> linhas(WidgetTester tester) {
    final rects = chips().evaluate().map((e) => tester.getRect(find.byWidget(e.widget))).toList()
      ..sort((a, b) => a.top != b.top ? a.top.compareTo(b.top) : a.left.compareTo(b.left));
    final grupos = <List<Rect>>[];
    for (final r in rects) {
      if (grupos.isEmpty || (grupos.last.first.top - r.top).abs() > 0.5) {
        grupos.add([r]);
      } else {
        grupos.last.add(r);
      }
    }
    return grupos;
  }

  /// Área de conteúdo da grade = largura do título "Horários em ..." (Column stretch).
  Rect area(WidgetTester tester) => tester.getRect(find.textContaining('Horários em'));

  void conferirGrade(WidgetTester tester, {required String caso}) {
    final g = linhas(tester);
    final a = area(tester);
    final colunas = g.first.length;
    expect(chips(), findsNWidgets(24), reason: caso);
    expect(g.expand((l) => l), hasLength(24), reason: caso);
    for (var i = 0; i < g.length; i++) {
      final linha = g[i];
      // todas as linhas cheias, menos (talvez) a última
      if (i < g.length - 1) expect(linha, hasLength(colunas), reason: '$caso linha $i');
      expect(linha.length, lessThanOrEqualTo(colunas), reason: '$caso linha $i');
      for (final r in linha) {
        expect(r.width, closeTo(linha.first.width, 0.01), reason: '$caso linha $i: $linha');
        expect(r.width, closeTo(g.first.first.width, 0.01), reason: '$caso: mesma largura em todas as linhas');
        expect(r.height, greaterThanOrEqualTo(48), reason: caso);
        expect(r.width, greaterThanOrEqualTo(48), reason: caso);
      }
      // mesma coluna = mesmo left em todas as linhas
      for (var c = 0; c < linha.length; c++) {
        expect(linha[c].left, closeTo(g.first[c].left, 0.01), reason: '$caso linha $i coluna $c');
      }
    }
    // a linha cheia vai da borda esquerda à direita da área de conteúdo
    expect(g.first.first.left, closeTo(a.left, 0.01), reason: '$caso: ${g.first} área=$a');
    expect(g.first.last.right, closeTo(a.right, 0.01), reason: '$caso: ${g.first} área=$a');
    // espaços iguais entre as colunas
    for (var c = 1; c < g.first.length; c++) {
      expect(g.first[c].left - g.first[c - 1].right, closeTo(8, 0.01), reason: caso);
    }
  }

  int colunas(WidgetTester tester) => linhas(tester).first.length;

  group('fonte de teste (flutter_test)', () {
    for (final largura in [360.0, 800.0]) {
      testWidgets('$largura dp: colunas de largura igual que preenchem a largura', (tester) async {
        await abrir(tester, largura);
        conferirGrade(tester, caso: '$largura');
        expect(colunas(tester), greaterThanOrEqualTo(2), reason: 'cabem 2 mesmo com a fonte de teste');
      });
    }

    testWidgets('800 dp tem mais colunas que 360 dp', (tester) async {
      await abrir(tester, 360);
      final em360 = colunas(tester);
      await abrir(tester, 800);
      final em800 = colunas(tester);
      expect(em800, greaterThan(em360));
      expect(em800, greaterThan(3));
    });

    testWidgets('texto a 200% em 360 dp: menos colunas, sem overflow, chips cabem na coluna', (tester) async {
      await abrir(tester, 360);
      final normal = colunas(tester);
      await abrir(tester, 360, escala: 2.0);
      expect(colunas(tester), lessThan(normal));
      conferirGrade(tester, caso: '360 a 200%');
      expect(tester.takeException(), isNull);
    });
  });

  group('Roboto (fonte do Android)', () {
    testWidgets('360 dp: 3 colunas iguais preenchendo a largura', (tester) async {
      await abrir(tester, 360, roboto: true);
      conferirGrade(tester, caso: 'roboto 360');
      expect(colunas(tester), 3);
    });

    testWidgets('800 dp: mais de 3 colunas iguais preenchendo a largura', (tester) async {
      await abrir(tester, 800, roboto: true);
      conferirGrade(tester, caso: 'roboto 800');
      expect(colunas(tester), greaterThan(3));
    });

    testWidgets('360 dp a 200%: menos colunas que a 100%, sem overflow', (tester) async {
      await abrir(tester, 360, escala: 2.0, roboto: true);
      conferirGrade(tester, caso: 'roboto 360 a 200%');
      expect(colunas(tester), lessThan(3));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('FASE 4 preservada: Keys no ChoiceChip, ícone e texto, indisponível desabilitado', (tester) async {
    await abrir(tester, 360);
    final livre = find.byKey(const Key('horario-08:00'));
    final ind = find.byKey(const Key('horario-indisponivel-09:00'));
    expect(tester.widget(livre), isA<ChoiceChip>());
    expect(tester.widget(ind), isA<ChoiceChip>());
    expect(tester.widget<ChoiceChip>(ind).onSelected, isNull);
    expect(tester.widget<ChoiceChip>(livre).onSelected, isNotNull);
    expect(find.descendant(of: ind, matching: find.byIcon(Icons.block)), findsOneWidget);
    expect(find.descendant(of: ind, matching: find.text('Indisponível')), findsOneWidget);
    expect(find.descendant(of: livre, matching: find.byIcon(Icons.schedule)), findsOneWidget);
    expect(find.descendant(of: livre, matching: find.text('Livre')), findsOneWidget);
    expect(find.text('Indisponível'), findsNWidgets(21));
    await tocarVisivel(tester, livre);
    expect(find.descendant(of: livre, matching: find.text('Escolhido')), findsOneWidget);
    expect(find.descendant(of: livre, matching: find.byIcon(Icons.check_circle)), findsOneWidget);
    // a grade não cria um Scrollable novo (o tocarVisivel rola o primeiro Scrollable vertical)
    expect(find.ancestor(of: livre, matching: find.byType(GridView)), findsNothing);
  });
}
