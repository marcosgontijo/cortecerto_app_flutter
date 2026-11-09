// FASE 4 (tester), critério 3: comportamento visual/usabilidade novo de cada tela, com APIs fake.
import 'dart:async';

import 'package:cortecerto_flutter/core/session/session_controller.dart';
import 'package:cortecerto_flutter/core/session/usuario.dart';
import 'package:cortecerto_flutter/core/theme/app_theme.dart';
import 'package:cortecerto_flutter/core/theme/app_tokens.dart';
import 'package:cortecerto_flutter/core/widgets/estados.dart';
import 'package:cortecerto_flutter/core/widgets/logout_button.dart';
import 'package:cortecerto_flutter/features/admin/domain/agendamento_admin.dart';
import 'package:cortecerto_flutter/features/agendamento/domain/status_agendamento.dart';
import 'package:cortecerto_flutter/features/agendamento/presentation/agendamento_controller.dart';
import 'package:cortecerto_flutter/features/agendamento/presentation/agendamento_page.dart';
import 'package:cortecerto_flutter/features/auth/data/auth_api.dart';
import 'package:cortecerto_flutter/features/auth/domain/auth_models.dart';
import 'package:cortecerto_flutter/features/auth/presentation/cadastro_controller.dart';
import 'package:cortecerto_flutter/features/auth/presentation/cadastro_page.dart';
import 'package:cortecerto_flutter/features/auth/presentation/login_controller.dart';
import 'package:cortecerto_flutter/features/auth/presentation/login_page.dart';
import 'package:cortecerto_flutter/features/meus_agendamentos/domain/meu_agendamento.dart';
import 'package:cortecerto_flutter/features/meus_agendamentos/presentation/meus_agendamentos_controller.dart';
import 'package:cortecerto_flutter/features/meus_agendamentos/presentation/meus_agendamentos_page.dart';
import 'package:cortecerto_flutter/features/servicos/domain/servico.dart';
import 'package:cortecerto_flutter/features/servicos/presentation/servicos_controller.dart';
import 'package:cortecerto_flutter/features/servicos/presentation/servicos_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../a11y/telas_harness.dart';
import '../helpers/fakes.dart';
import '../helpers/widget_helpers.dart';

TextField campo(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField)));

/// Volta 4 (tester): posição da ação nos cards de lista (MASTER.md "Card de lista: ... ação à direita").
/// Em 800 dp, mede a superfície do card (o Material do Card, sem a margem), a informação da esquerda
/// e o botão de ação. Pega o defeito do Wrap(spaceBetween) sob largura frouxa (Column start), em que o
/// botão fica colado à informação, à esquerda.
void conferirAcaoADireita(WidgetTester tester, AppTokens t, Finder card, Finder info, Finder acao) {
  final superficie = tester.getRect(find.descendant(of: card, matching: find.byType(Material)).first);
  final i = tester.getRect(info);
  final b = tester.getRect(acao);
  final dados = 'card=$superficie info=$i acao=$b';
  // borda direita do botão = borda direita do conteúdo do card (superfície menos o padding t.md)
  expect(superficie.right - b.right, closeTo(t.md, 0.01), reason: dados);
  // a informação continua na borda esquerda do conteúdo
  expect(i.left - superficie.left, closeTo(t.md, 0.01), reason: dados);
  // mesma linha (em 800 dp cabem os dois) e espaço de verdade entre eles
  expect((i.center.dy - b.center.dy).abs(), lessThan(1), reason: dados);
  expect(b.left - i.right, greaterThan(200), reason: dados);
}

void main() {
  final tema = AppTheme.darkTheme;
  final t = tema.extension<AppTokens>()!;

  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    registrarFallbacks();
    registerFallbackValue(const CadastroRequest(
        nome: '', telefone: '', cpf: '', email: '', dataNascimento: '', senha: '', confirmarSenha: ''));
  });

  group('Login', () {
    late MockAuthApi api;
    late SessionController s;
    Widget montar() => comRouter(const LoginPage(), providers: [
          ChangeNotifierProvider<SessionController>.value(value: s),
          Provider<AuthApi>.value(value: api),
          ChangeNotifierProvider(create: (_) => LoginController(api, s)),
        ]);
    setUp(() {
      api = MockAuthApi();
      s = SessionController(FakeTokenStorage());
    });

    testWidgets('marca, rótulos, ícones, next/done, autofill', (tester) async {
      await tester.pumpWidget(montar());
      expect(find.text('CorteCerto'), findsOneWidget);
      expect(find.text('Bem-vindo'), findsOneWidget);
      final cpf = campo(tester, 'campo-cpf');
      final senha = campo(tester, 'campo-senha');
      expect(cpf.textInputAction, TextInputAction.next);
      expect(cpf.autofillHints, contains(AutofillHints.username));
      expect(cpf.decoration?.labelText, 'CPF');
      expect(cpf.decoration?.prefixIcon, isNotNull);
      expect(senha.textInputAction, TextInputAction.done);
      expect(senha.autofillHints, contains(AutofillHints.password));
      expect(senha.decoration?.labelText, 'Senha');
      expect(senha.decoration?.prefixIcon, isNotNull);
      expect(find.byType(AutofillGroup), findsOneWidget);
    });

    testWidgets('"done" na senha envia (login chamado 1 vez com o CPF só dígitos)', (tester) async {
      when(() => api.login(cpf: any(named: 'cpf'), senha: any(named: 'senha'))).thenAnswer((_) async =>
          const LoginResponse(token: 'tok', usuario: Usuario(id: 1, nome: 'Maria', role: 'CLIENTE')));
      await tester.pumpWidget(montar());
      await tester.enterText(find.byKey(const Key('campo-cpf')), '52998224725');
      await tester.enterText(find.byKey(const Key('campo-senha')), 'abc12345');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      verify(() => api.login(cpf: '52998224725', senha: 'abc12345')).called(1);
    });

    testWidgets('mostrar/ocultar senha com rótulo acessível', (tester) async {
      await tester.pumpWidget(montar());
      expect(campo(tester, 'campo-senha').obscureText, isTrue);
      expect(find.byTooltip('Mostrar senha'), findsOneWidget);
      await tester.tap(find.byTooltip('Mostrar senha'));
      await tester.pump();
      expect(campo(tester, 'campo-senha').obscureText, isFalse);
      expect(find.byTooltip('Ocultar senha'), findsOneWidget);
    });

    testWidgets('erro do servidor aparece UMA vez, perto do botão', (tester) async {
      when(() => api.login(cpf: any(named: 'cpf'), senha: any(named: 'senha'))).thenThrow(semConexao);
      await tester.pumpWidget(montar());
      await tester.enterText(find.byKey(const Key('campo-cpf')), '52998224725');
      await tester.enterText(find.byKey(const Key('campo-senha')), 'abc12345');
      await tester.tap(find.byKey(const Key('botao-entrar')));
      await tester.pumpAndSettle();
      expect(find.text(semConexao.mensagem), findsOneWidget);
      final erro = tester.getRect(find.byKey(const Key('erro-login')));
      final botao = tester.getRect(find.byKey(const Key('botao-entrar')));
      expect(botao.top - erro.bottom, inInclusiveRange(0, 48));
    });
  });

  group('Cadastro', () {
    late MockAuthApi api;
    Widget montar() => comRouter(const CadastroPage(), providers: [
          ChangeNotifierProvider<SessionController>.value(value: SessionController(FakeTokenStorage())),
          ChangeNotifierProvider(create: (_) => CadastroController(api)),
        ]);
    setUp(() => api = MockAuthApi());
    const campos = ['nome', 'telefone', 'cpf', 'email', 'dataNascimento', 'senha', 'confirmarSenha'];

    testWidgets('next em todos, done só no último; autofill; ícone e rótulo em todos', (tester) async {
      await tester.pumpWidget(montar());
      for (final c in campos) {
        final tf = campo(tester, 'campo-$c');
        expect(tf.textInputAction, c == 'confirmarSenha' ? TextInputAction.done : TextInputAction.next,
            reason: c);
        expect(tf.decoration?.labelText, isNotEmpty, reason: c);
        expect(tf.decoration?.prefixIcon, isNotNull, reason: c);
        expect(tf.autofillHints, isNotEmpty, reason: c);
      }
      expect(campo(tester, 'campo-nome').autofillHints, contains(AutofillHints.name));
      expect(campo(tester, 'campo-email').autofillHints, contains(AutofillHints.email));
      expect(campo(tester, 'campo-senha').autofillHints, contains(AutofillHints.newPassword));
      expect(find.byTooltip('Mostrar senha'), findsNWidgets(2));
    });

    testWidgets('"done" no confirmarSenha com o form válido chama cadastrar 1 vez', (tester) async {
      when(() => api.cadastrar(any())).thenAnswer((_) async {});
      await tester.pumpWidget(montar());
      await tester.enterText(find.byKey(const Key('campo-nome')), 'Maria Silva');
      await tester.enterText(find.byKey(const Key('campo-telefone')), '11987654321');
      await tester.enterText(find.byKey(const Key('campo-cpf')), '52998224725');
      await tester.enterText(find.byKey(const Key('campo-email')), 'maria@mail.com');
      await tester.enterText(find.byKey(const Key('campo-dataNascimento')), '15031990');
      await tester.enterText(find.byKey(const Key('campo-senha')), 'abc12345');
      await tester.enterText(find.byKey(const Key('campo-confirmarSenha')), 'abc12345');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      verify(() => api.cadastrar(any())).called(1);
    });

    testWidgets('"done" com form inválido NÃO chama a API', (tester) async {
      await tester.pumpWidget(montar());
      await tester.showKeyboard(find.byKey(const Key('campo-confirmarSenha')));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      verifyNever(() => api.cadastrar(any()));
    });

    testWidgets('link para o Login', (tester) async {
      await tester.pumpWidget(montar());
      await tester.ensureVisible(find.byKey(const Key('link-login')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('link-login')));
      await tester.pumpAndSettle();
      expect(find.text('TELA login'), findsOneWidget);
    });
  });

  group('Navegação do cliente', () {
    Future<void> confereBarra(WidgetTester tester, int indice) async {
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, indice);
      expect(find.byKey(const Key('botao-sair')), findsOneWidget);
      expect(find.byType(LogoutButton), findsOneWidget);
    }

    testWidgets('Serviços: barra (índice 0), logout e destinos levam às rotas', (tester) async {
      await abrirTela(tester, TelaF4.servicos);
      await confereBarra(tester, 0);
      await tester.tap(find.byKey(const Key('botao-meus-agendamentos')));
      await tester.pumpAndSettle();
      expect(find.text('TELA meus'), findsOneWidget);
    });

    testWidgets('Serviços → Produtos pela barra', (tester) async {
      await abrirTela(tester, TelaF4.servicos);
      await tester.tap(find.byKey(const Key('botao-produtos')));
      await tester.pumpAndSettle();
      expect(find.text('TELA produtos'), findsOneWidget);
    });

    testWidgets('Meus: barra (índice 1) e logout; destino Serviços', (tester) async {
      await abrirTela(tester, TelaF4.meus);
      await confereBarra(tester, 1);
      await tester.tap(find.byKey(const Key('nav-servicos')));
      await tester.pumpAndSettle();
      expect(find.text('TELA servicos'), findsOneWidget);
    });

    testWidgets('Produtos: barra (índice 2) e logout; destino Meus', (tester) async {
      await abrirTela(tester, TelaF4.produtos);
      await confereBarra(tester, 2);
      await tester.tap(find.byKey(const Key('botao-meus-agendamentos')));
      await tester.pumpAndSettle();
      expect(find.text('TELA meus'), findsOneWidget);
    });

    testWidgets('Agendamento e Confirmado ficam fora da barra', (tester) async {
      await abrirTela(tester, TelaF4.agendamento, estado: EstadoF4.inicial);
      expect(find.byType(NavigationBar), findsNothing);
      await abrirTela(tester, TelaF4.confirmado);
      expect(find.byType(NavigationBar), findsNothing);
    });
  });

  group('Serviços', () {
    testWidgets('cada card tem "Agendar" e tocar leva ao agendamento do serviço', (tester) async {
      await abrirTela(tester, TelaF4.servicos);
      expect(find.text('Agendar'), findsNWidgets(2));
      expect(find.text(r'R$ 35,00'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byKey(const Key('servico-2')), matching: find.text('Agendar')));
      await tester.pumpAndSettle();
      expect(find.text('TELA agendamento Barba'), findsOneWidget);
    });

    testWidgets('erro usa EstadoErro', (tester) async {
      await abrirTela(tester, TelaF4.servicos, estado: EstadoF4.erro);
      expect(find.byType(EstadoErro), findsOneWidget);
    });

    testWidgets('vazio usa EstadoVazio', (tester) async {
      await abrirTela(tester, TelaF4.servicos, estado: EstadoF4.vazio);
      expect(find.byType(EstadoVazio), findsOneWidget);
    });

    testWidgets('card: "Agendar" na borda direita do conteúdo do card (800 dp)', (tester) async {
      tester.view.physicalSize = const Size(2400, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await abrirTela(tester, TelaF4.servicos);
      for (final (id, preco) in const [(1, r'R$ 35,00'), (2, r'R$ 25,00')]) {
        final card = find.byKey(Key('servico-$id'));
        conferirAcaoADireita(
          tester,
          t,
          card,
          find.descendant(of: card, matching: find.text(preco)),
          find.ancestor(
              of: find.descendant(of: card, matching: find.text('Agendar')),
              matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)),
        );
      }
    });

    testWidgets('carregando usa EstadoCarregando', (tester) async {
      final api = MockServicosApi();
      final c = Completer<List<Servico>>();
      when(() => api.listar()).thenAnswer((_) => c.future);
      final s = SessionController(FakeTokenStorage());
      await s.iniciar('t', const Usuario(id: 3, nome: 'Maria', role: 'CLIENTE'));
      await tester.pumpWidget(comRouter(const ServicosPage(), providers: [
        ChangeNotifierProvider<SessionController>.value(value: s),
        ChangeNotifierProvider(create: (_) => ServicosController(api)),
      ]));
      await tester.pump();
      expect(find.byType(EstadoCarregando), findsOneWidget);
      c.complete(const []);
      await tester.pumpAndSettle();
    });
  });

  group('Produtos', () {
    testWidgets('360x640 com 2.0: o último produto fica ACIMA da barra; barra com SafeArea e total',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await abrirTela(tester, TelaF4.produtos);
      final barra = find.byKey(const Key('produtos-barra'));
      // contexto.md (Produtos) pede a SafeArea; o efeito dela é medido em 'barra respeita os recuos...'
      expect(find.descendant(of: barra, matching: find.byType(SafeArea)), findsOneWidget);
      expect(find.descendant(of: barra, matching: find.byKey(const Key('produtos-total'))), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('produtos-total'))).data, startsWith('Total: R\$'));
      // rola a lista até o fim
      final lista = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
      final st = tester.state<ScrollableState>(lista.first);
      st.position.jumpTo(st.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final ultimo = find.byWidgetPredicate((w) => w is CheckboxListTile).last;
      expect(tester.getRect(ultimo).bottom, lessThanOrEqualTo(tester.getRect(barra).top));
    });

    // Review volta 1 (sugestão 6): em vez de exigir que exista uma SafeArea, mede o efeito.
    // Recuos laterais (entalhe em paisagem) empurram o conteúdo da barra para dentro; o recuo
    // inferior é tratado pela NavigationBar, e a barra fica acima dela.
    testWidgets('barra respeita os recuos do sistema (laterais e inferior)', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0; // 360x640 lógicos
      addTearDown(tester.view.reset);

      Future<({double esq, double dir, Rect barra, Rect nav, Rect total})> medir() async {
        await abrirTela(tester, TelaF4.produtos);
        final barra = tester.getRect(find.byKey(const Key('produtos-barra')));
        final total = tester.getRect(find.byKey(const Key('produtos-total')));
        // área de conteúdo da barra: o Padding mais próximo acima do Wrap (independe de como
        // o Wrap distribui os textos e de a barra encolher ou esticar)
        final conteudo = tester.getRect(find
            .ancestor(
                of: find.descendant(of: find.byKey(const Key('produtos-barra')), matching: find.byType(Wrap)),
                matching: find.byType(Padding))
            .first);
        final nav = tester.getRect(find.byType(NavigationBar));
        return (esq: conteudo.left - barra.left, dir: barra.right - conteudo.right, barra: barra, nav: nav, total: total);
      }

      final sem = await medir();
      // 120 px físicos = 40 lógicos de cada lado; 90 px = 30 lógicos embaixo
      tester.view.padding = const FakeViewPadding(left: 120, right: 120, bottom: 90);
      tester.view.viewPadding = const FakeViewPadding(left: 120, right: 120, bottom: 90);
      await tester.pumpWidget(const SizedBox());
      final com = await medir();
      expect(com.esq - sem.esq, closeTo(40, 0.01), reason: 'recuo esquerdo não aplicado (esq=${com.esq})');
      expect(com.dir - sem.dir, closeTo(40, 0.01), reason: 'recuo direito não aplicado (dir=${com.dir})');
      // barra acima da NavigationBar, e o total fora da faixa do recuo inferior
      expect(com.barra.bottom, lessThanOrEqualTo(com.nav.top));
      expect(com.total.bottom, lessThanOrEqualTo(640 - 30));
    });

    // Achado do tester (volta 2): a barra (fundo surfaceHigh + borda de cima) é filha de um
    // Column centralizado no bottomNavigationBar e o Wrap encolhe ao conteúdo; em 360 dp ela
    // ocupa só x=42.9..317.1 e o WrapAlignment.spaceBetween não tem efeito. Uma "barra
    // inferior fixa" (MASTER.md: bottom bar em surfaceHigh) precisa ir de borda a borda,
    // como a NavigationBar logo abaixo.
    for (final largura in [360.0, 800.0]) {
      testWidgets('barra de total ocupa a largura toda da tela ($largura dp)', (tester) async {
        tester.view.physicalSize = Size(largura * 3, 1920);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);
        await abrirTela(tester, TelaF4.produtos);
        final barra = tester.getRect(find.byKey(const Key('produtos-barra')));
        final nav = tester.getRect(find.byType(NavigationBar));
        expect(barra.left, nav.left, reason: 'barra=$barra nav=$nav');
        expect(barra.right, nav.right, reason: 'barra=$barra nav=$nav');
        expect(barra.width, largura);
      });
    }

    // Volta 3 (tester): com a barra de borda a borda, o WrapAlignment.spaceBetween tem que
    // jogar a quantidade para a esquerda e o total para a direita da área de conteúdo.
    // Em 800 dp os dois textos cabem numa linha (em 360 dp a fonte de teste quebra o Wrap).
    testWidgets('quantidade e total nas pontas da barra (spaceBetween efetivo, 800 dp)', (tester) async {
      tester.view.physicalSize = const Size(2400, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await abrirTela(tester, TelaF4.produtos);
      final barraF = find.byKey(const Key('produtos-barra'));
      final barra = tester.getRect(barraF);
      // área de conteúdo = o Wrap; ele tem que ocupar a barra menos o recuo horizontal (t.md)
      final conteudo = tester.getRect(find.descendant(of: barraF, matching: find.byType(Wrap)));
      expect(conteudo.left - barra.left, closeTo(t.md, 0.01), reason: 'wrap=$conteudo barra=$barra');
      expect(barra.right - conteudo.right, closeTo(t.md, 0.01), reason: 'wrap=$conteudo barra=$barra');
      final qtd = tester.getRect(find.descendant(of: barraF, matching: find.text('1 selecionado')));
      final total = tester.getRect(find.byKey(const Key('produtos-total')));
      // mesma linha do Wrap (senão spaceBetween não se aplica entre os dois)
      expect((qtd.center.dy - total.center.dy).abs(), lessThan(1), reason: 'qtd=$qtd total=$total');
      expect(qtd.left, closeTo(conteudo.left, 0.01), reason: 'qtd=$qtd conteudo=$conteudo');
      expect(total.right, closeTo(conteudo.right, 0.01), reason: 'total=$total conteudo=$conteudo');
      // e há espaço de verdade entre eles (não estão colados por spacing)
      expect(total.left - qtd.right, greaterThan(100));
    });

    testWidgets('seleção também por check (não só cor)', (tester) async {
      await abrirTela(tester, TelaF4.produtos);
      final tile = tester.widget<CheckboxListTile>(find.byKey(const Key('produto-1')));
      expect(tile.value, isTrue);
      expect(find.text('1 selecionado'), findsOneWidget);
    });
  });

  group('Agendamento', () {
    late MockAgendamentoApi api;
    late SessionController s;
    const servico = Servico(id: 1, tipoServico: 'Corte Simples', precoServico: '35.00');
    Widget montar() => comRouter(AgendamentoPage(servico: servico, hoje: DateTime(2030, 1, 10)), providers: [
          ChangeNotifierProvider<SessionController>.value(value: s),
          ChangeNotifierProvider(create: (_) => AgendamentoController(api)),
        ]);
    setUp(() async {
      api = MockAgendamentoApi();
      s = SessionController(FakeTokenStorage());
      await s.iniciar('t', const Usuario(id: 3, nome: 'Maria', role: 'CLIENTE'));
      when(() => api.disponibilidades(any())).thenAnswer((_) async => ['08:00', '08:30', '10:00']);
    });

    bool selecionada(WidgetTester tester, String k) =>
        isSemantics(isSelected: true).matches(tester.getSemantics(find.byKey(Key(k))), {});

    testWidgets('etapa derivada do estado: Data → Horário → Confirmar; serviço no topo', (tester) async {
      final h = tester.ensureSemantics();
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('agendamento-servico'))).data, 'Corte Simples');
      expect(selecionada(tester, 'etapa-data'), isTrue);
      expect(selecionada(tester, 'etapa-horario'), isFalse);
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      expect(selecionada(tester, 'etapa-data'), isFalse);
      expect(selecionada(tester, 'etapa-horario'), isTrue);
      await tocarVisivel(tester, find.byKey(const Key('horario-08:30')));
      expect(selecionada(tester, 'etapa-confirmar'), isTrue);
      expect(selecionada(tester, 'etapa-horario'), isFalse);
      expect(tester.getSemantics(find.byKey(const Key('etapa-data'))).label, contains('concluída'));
      h.dispose();
    });

    testWidgets('chips >= 48x48; indisponível desabilitado com ícone block e texto', (tester) async {
      await tester.pumpWidget(montar());
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      final livre = tester.getSize(find.byKey(const Key('horario-08:00')));
      expect(livre.width, greaterThanOrEqualTo(48));
      expect(livre.height, greaterThanOrEqualTo(48));
      final ind = find.byKey(const Key('horario-indisponivel-09:00'));
      expect(tester.getSize(ind).height, greaterThanOrEqualTo(48));
      expect(tester.widget<ChoiceChip>(ind).onSelected, isNull);
      expect(find.descendant(of: ind, matching: find.byIcon(Icons.block)), findsOneWidget);
      expect(find.descendant(of: ind, matching: find.text('Indisponível')), findsOneWidget);
      // livres e indisponíveis = grade inteira (24)
      expect(find.byWidgetPredicate((w) => w is ChoiceChip), findsNWidgets(24));
      expect(find.text('Indisponível'), findsNWidgets(21));
    });

    testWidgets('resumo com serviço, data, horário e preço; CTA fixo habilita só com horário',
        (tester) async {
      await tester.pumpWidget(montar());
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      ButtonStyleButton cta() => tester.widget<ButtonStyleButton>(find.descendant(
          of: find.byKey(const Key('botao-confirmar')), matching: find.bySubtype<ButtonStyleButton>()));
      expect(cta().onPressed, isNull);
      expect(find.byKey(const Key('agendamento-resumo')), findsNothing);
      final antes = tester.getRect(find.byKey(const Key('botao-confirmar')));
      await tocarVisivel(tester, find.byKey(const Key('horario-10:00')));
      expect(cta().onPressed, isNotNull);
      final resumo = find.byKey(const Key('agendamento-resumo'));
      final texto = tester
          .widgetList<RichText>(find.descendant(of: resumo, matching: find.byType(RichText)))
          .map((r) => r.text.toPlainText())
          .join(' | ');
      expect(texto, contains('Corte Simples'));
      expect(texto, contains('15/01/2030'));
      expect(texto, contains('10:00'));
      expect(texto, contains(r'R$ 35,00'));
      // o CTA não rolou junto com o conteúdo
      expect(tester.getRect(find.byKey(const Key('botao-confirmar'))), antes);
      expect(find.ancestor(of: find.byKey(const Key('botao-confirmar')), matching: find.byType(SingleChildScrollView)),
          findsNothing);
    });

    // Volta 3 (tester), achado 2 do review volta 2: o AnimatedSwitcher passa largura frouxa e o
    // resumo encolhia até a linha mais larga (W=390.5 em 800 dp). Tem que ter a largura do card
    // do calendário logo acima. 800 dp porque em 360 dp a fonte de teste quebra a linha e esconde.
    for (final largura in [360.0, 800.0]) {
      testWidgets('resumo tem a largura do card do calendário ($largura dp)', (tester) async {
        tester.view.physicalSize = Size(largura * 3, 1920 * 1.5);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(montar());
        await tester.pumpAndSettle();
        await tocarVisivel(tester, find.text('15'));
        await tocarVisivel(tester, find.byKey(const Key('horario-10:00')));
        final resumo = tester.getRect(find.byKey(const Key('agendamento-resumo')));
        final cal = tester.getRect(
            find.ancestor(of: find.byKey(const Key('calendario')), matching: find.byType(Card)).first);
        expect(resumo.width, closeTo(cal.width, 0.01), reason: 'resumo=$resumo calendario=$cal');
        expect(resumo.left, closeTo(cal.left, 0.01), reason: 'resumo=$resumo calendario=$cal');
        expect(resumo.right, closeTo(cal.right, 0.01), reason: 'resumo=$resumo calendario=$cal');
      });
    }
  });

  group('Confirmado', () {
    testWidgets('ícone de sucesso na cor success; CTA primário e secundário', (tester) async {
      await abrirTela(tester, TelaF4.confirmado);
      expect(find.text('Agendamento confirmado!'), findsOneWidget);
      final icone = tester.widgetList<Icon>(find.byIcon(Icons.check_circle)).first;
      expect(icone.color, t.success);
      expect(tester.widget(find.byKey(const Key('botao-meus-agendamentos'))), isA<FilledButton>());
      expect(tester.widget(find.byKey(const Key('botao-voltar-servicos'))), isA<OutlinedButton>());
      expect(find.text('Ver meus agendamentos'), findsOneWidget);
      expect(find.text('Voltar aos serviços'), findsOneWidget);
    });
  });

  group('Meus Agendamentos', () {
    testWidgets('aba vazia: "Agendar um horário" leva a /servicos', (tester) async {
      await abrirTela(tester, TelaF4.meus, estado: EstadoF4.vazio);
      expect(find.byType(EstadoVazio), findsOneWidget);
      await tester.tap(find.text('Agendar um horário'));
      await tester.pumpAndSettle();
      expect(find.text('TELA servicos'), findsOneWidget);
    });

    testWidgets('aba Histórico vazia também tem estado vazio com a ação', (tester) async {
      final api = MockAgendamentoApi();
      when(() => api.meus()).thenAnswer((_) async =>
          [MeuAgendamento(id: 1, data: DateTime(2030, 1, 20), horario: '09:00', status: StatusAgendamento.pendente, servico: 'Barba')]);
      final s = SessionController(FakeTokenStorage());
      await s.iniciar('t', const Usuario(id: 3, nome: 'Maria', role: 'CLIENTE'));
      await tester.pumpWidget(comRouter(const MeusAgendamentosPage(), providers: [
        ChangeNotifierProvider<SessionController>.value(value: s),
        ChangeNotifierProvider(create: (_) => MeusAgendamentosController(api, relogio: () => DateTime(2030, 1, 15))),
      ]));
      await tester.pumpAndSettle();
      expect(find.byType(EstadoVazio), findsNothing);
      await tester.tap(find.byKey(const Key('aba-historico')));
      await tester.pumpAndSettle();
      expect(find.byType(EstadoVazio), findsOneWidget);
      expect(find.text('Agendar um horário'), findsOneWidget);
    });

    testWidgets('card com data/horário em destaque (>= titleMedium) e StatusChip', (tester) async {
      await abrirTela(tester, TelaF4.meus);
      final card = find.byKey(const Key('meu-agendamento-1'));
      expect(find.descendant(of: card, matching: find.byType(StatusChip)), findsOneWidget);
      final textos = tester.widgetList<Text>(find.descendant(of: card, matching: find.byType(Text)));
      final comHora = textos.where((x) => (x.data ?? '').contains('09:00'));
      expect(comHora, isNotEmpty);
      final tamanho = comHora.first.style?.fontSize ?? 0;
      expect(tamanho, greaterThanOrEqualTo(tema.textTheme.titleMedium!.fontSize!));
    });

    testWidgets('card: "Cancelar" na borda direita do conteúdo do card (800 dp)', (tester) async {
      tester.view.physicalSize = const Size(2400, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await abrirTela(tester, TelaF4.meus);
      // ids 1 (confirmado) e 4 (pendente) estão na aba Próximos e podem ser cancelados
      for (final id in const [1, 4]) {
        final card = find.byKey(Key('meu-agendamento-$id'));
        expect(find.byKey(Key('botao-cancelar-$id')), findsOneWidget);
        conferirAcaoADireita(tester, t, card, find.descendant(of: card, matching: find.byType(StatusChip)),
            find.byKey(Key('botao-cancelar-$id')));
      }
    });

    testWidgets('erro com "Tentar novamente"', (tester) async {
      await abrirTela(tester, TelaF4.meus, estado: EstadoF4.erro);
      expect(find.byType(EstadoErro), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
    });
  });

  group('Painel Admin', () {
    testWidgets('card Agenda grande (>= 72) com ícone >= 32', (tester) async {
      await abrirTela(tester, TelaF4.painelAdmin);
      expect(find.text('Painel Admin'), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('card-agenda'))).height, greaterThanOrEqualTo(72));
      final icone = tester.widget<Icon>(
          find.descendant(of: find.byKey(const Key('card-agenda')), matching: find.byIcon(Icons.calendar_month)));
      expect(icone.size, greaterThanOrEqualTo(32));
    });
  });

  group('Agenda Admin', () {
    testWidgets('FAB com Key e tooltip; filtros com contador dentro; sem DESCONHECIDO', (tester) async {
      await abrirTela(tester, TelaF4.agendaAdmin);
      final fab = find.byKey(const Key('botao-novo-agendamento'));
      expect(fab, findsOneWidget);
      expect(tester.widget(fab), isA<FloatingActionButton>());
      expect(find.byTooltip('Novo agendamento'), findsOneWidget);
      for (final k in ['PENDENTE', 'CONFIRMADO', 'CANCELADO', 'REALIZADO']) {
        expect(
            find.descendant(of: find.byKey(Key('filtro-$k')), matching: find.byKey(Key('contador-$k-valor'))),
            findsOneWidget,
            reason: k);
        expect(tester.widget<Text>(find.byKey(Key('contador-$k-valor'))).data, '1');
      }
      expect(find.descendant(of: find.byKey(const Key('filtro-todos')), matching: find.byKey(const Key('contador-total-valor'))),
          findsOneWidget);
      expect(find.byKey(const Key('filtro-DESCONHECIDO')), findsNothing);
      expect(tester.widget(find.byKey(const Key('filtro-PENDENTE'))), isA<FilterChip>());
    });

    testWidgets('slot livre "Disponível" com ícone de adicionar; ocupado com StatusChip', (tester) async {
      await abrirTela(tester, TelaF4.agendaAdmin);
      expect(find.byKey(const Key('slot-adicionar')), findsWidgets);
      expect(find.text('Disponível'), findsWidgets);
      expect(find.descendant(of: find.byKey(const Key('agenda-horario-09:00')), matching: find.byType(StatusChip)),
          findsOneWidget);
    });

    testWidgets('detalhes: Cancelar e Excluir em error, separados por Divider', (tester) async {
      await abrirTela(tester, TelaF4.agendaAdmin, estado: EstadoF4.detalhes);
      for (final k in ['acao-cancelar', 'acao-excluir']) {
        final b = tester.widget<ButtonStyleButton>(find.byKey(Key(k)));
        expect(b.style?.foregroundColor?.resolve(<WidgetState>{}), tema.colorScheme.error, reason: k);
      }
      final confirmar = tester.getRect(find.byKey(const Key('acao-confirmar')));
      final cancelar = tester.getRect(find.byKey(const Key('acao-cancelar')));
      final divisor = find.descendant(of: find.byKey(const Key('detalhes-agendamento')), matching: find.byType(Divider));
      expect(divisor, findsWidgets);
      final yDiv = tester.getRect(divisor.last).center.dy;
      expect(confirmar.bottom, lessThan(yDiv));
      expect(cancelar.top, greaterThan(yDiv));
    });
  });

  group('Formulário admin', () {
    testWidgets('busca: search, tooltip, rótulo e ícone; vazio com EstadoVazio', (tester) async {
      await abrirTela(tester, TelaF4.formAdmin, estado: EstadoF4.vazio);
      final busca = tester.widget<TextField>(find.byKey(const Key('campo-busca-cliente')));
      expect(busca.textInputAction, TextInputAction.search);
      expect(busca.decoration?.labelText, isNotEmpty);
      expect(busca.decoration?.prefixIcon, isNotNull);
      expect(find.byTooltip('Buscar cliente'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('form-clientes-vazio')), matching: find.byType(EstadoVazio)),
          findsNothing); // a própria Key está no EstadoVazio
      expect(tester.widget(find.byKey(const Key('form-clientes-vazio'))), isA<EstadoVazio>());
    });

    // Volta 3 (tester), sugestão 4 do review volta 2: a ligação EstadoErro -> carregarHorarios
    // na tela. A 1a chamada falha, "Tentar novamente" chama disponibilidades de novo e a grade aparece.
    testWidgets('horários: erro com "Tentar novamente" recarrega e mostra a grade', (tester) async {
      var chamadas = 0;
      final datas = <DateTime>[];
      await abrirTela(tester, TelaF4.formAdmin, estado: EstadoF4.erro, horariosForm: (d) async {
        chamadas++;
        datas.add(d);
        if (chamadas == 1) throw semConexao;
        return ['12:00', '12:30'];
      });
      final erro = find.byKey(const Key('form-erro-horarios'));
      expect(erro, findsOneWidget);
      expect(tester.widget(erro), isA<EstadoErro>());
      expect(find.descendant(of: erro, matching: find.textContaining('conex')), findsWidgets);
      expect(find.byKey(const Key('form-horario-12:00')), findsNothing);
      expect(chamadas, 1);
      await tocarVisivel(tester, find.descendant(of: erro, matching: find.text('Tentar novamente')));
      expect(chamadas, 2);
      expect(datas, [diaTeste, diaTeste]);
      expect(find.byKey(const Key('form-erro-horarios')), findsNothing);
      expect(find.byKey(const Key('form-horario-12:00')), findsOneWidget);
      expect(find.byKey(const Key('form-horario-12:30')), findsOneWidget);
    });

    // Volta 4 (tester), pendência 2 do feedback volta 3: a lista de serviços do Form vem da API e
    // precisa de "Tentar novamente" ligado ao recarregar do controller (iniciar).
    testWidgets('serviços: erro com "Tentar novamente" recarrega e mostra os chips', (tester) async {
      var chamadas = 0;
      var chamadasHorarios = 0;
      await abrirTela(tester, TelaF4.formAdmin, estado: EstadoF4.erroServicos, servicosForm: () async {
        chamadas++;
        if (chamadas == 1) throw semConexao;
        return const [servicoTeste, barbaTeste];
      }, horariosForm: (_) async {
        chamadasHorarios++;
        return ['12:00', '12:30'];
      });
      final erro = find.byKey(const Key('form-erro-servicos'));
      expect(erro, findsOneWidget);
      expect(tester.widget(erro), isA<EstadoErro>());
      expect(find.descendant(of: erro, matching: find.textContaining('conex')), findsWidgets);
      expect(find.byKey(const Key('form-servico-1')), findsNothing);
      expect(chamadas, 1);
      await tocarVisivel(tester, find.descendant(of: erro, matching: find.text('Tentar novamente')));
      expect(chamadas, 2);
      // iniciar() também recarrega os horários (efeito documentado no dev.md volta 4)
      expect(chamadasHorarios, 2);
      expect(find.byKey(const Key('form-erro-servicos')), findsNothing);
      expect(find.byKey(const Key('form-servico-1')), findsOneWidget);
      expect(find.byKey(const Key('form-servico-2')), findsOneWidget);
      // os horários continuam na tela depois do recarregar
      expect(find.byKey(const Key('form-horario-12:00')), findsOneWidget);
      // e o chip recarregado funciona
      await tocarVisivel(tester, find.byKey(const Key('form-servico-2')));
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('form-servico-2'))).selected, isTrue);
    });

    testWidgets('serviços vazios: EstadoVazio com Key form-servicos-vazio e nenhum chip', (tester) async {
      await abrirTela(tester, TelaF4.formAdmin, estado: EstadoF4.vazioServicos);
      final vazio = find.byKey(const Key('form-servicos-vazio'));
      expect(vazio, findsOneWidget);
      expect(tester.widget(vazio), isA<EstadoVazio>());
      expect(find.descendant(of: vazio, matching: find.text('Nenhum serviço cadastrado.')), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is ChoiceChip && '${w.key}'.contains('form-servico-')), findsNothing);
      expect(find.byKey(const Key('form-erro-servicos')), findsNothing);
      // os horários não são afetados (a lista é preguiçosa: rola até construir)
      await tester.scrollUntilVisible(find.byKey(const Key('form-horario-12:00')), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const Key('form-horario-12:00')), findsOneWidget);
    });

    testWidgets('horários vazios: EstadoVazio com Key form-horarios-vazio e nenhum chip', (tester) async {
      await abrirTela(tester, TelaF4.formAdmin, estado: EstadoF4.vazioHorarios);
      final vazio = find.byKey(const Key('form-horarios-vazio'));
      expect(vazio, findsOneWidget);
      expect(tester.widget(vazio), isA<EstadoVazio>());
      expect(find.descendant(of: vazio, matching: find.text('Nenhum horário livre nesta data.')), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is ChoiceChip && '${w.key}'.contains('form-horario-')), findsNothing);
      // os serviços continuam
      expect(find.byKey(const Key('form-servico-1')), findsOneWidget);
    });

    testWidgets('carregando serviços e horários: EstadoCarregando com rótulo; ao terminar some', (tester) async {
      final cs = Completer<List<Servico>>();
      final ch = Completer<List<String>>();
      final h = tester.ensureSemantics();
      await abrirTela(tester, TelaF4.formAdmin,
          estado: EstadoF4.erro, servicosForm: () => cs.future, horariosForm: (_) => ch.future, assentar: false);
      expect(find.byType(EstadoCarregando), findsNWidgets(2));
      expect(find.bySemanticsLabel('Carregando serviços'), findsOneWidget);
      expect(find.bySemanticsLabel('Carregando horários'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      cs.complete(const [servicoTeste]);
      await tester.pump();
      expect(find.bySemanticsLabel('Carregando serviços'), findsNothing);
      expect(find.byKey(const Key('form-servico-1')), findsOneWidget);
      expect(find.bySemanticsLabel('Carregando horários'), findsOneWidget);
      ch.complete(['12:00']);
      await tester.pumpAndSettle();
      expect(find.byType(EstadoCarregando), findsNothing);
      expect(find.byKey(const Key('form-horario-12:00')), findsOneWidget);
      h.dispose();
    });

    // Volta 5 (tester), achado IMPORTANTE 1 do review volta 4: a busca de clientes vem da API e o
    // erro precisa ser EstadoErro com "Tentar novamente" que repete buscarClientes(texto do campo).
    // Pega: BlocoErro/texto solto com a mesma Key (isA), retry sem efeito ou ligado a outra ação
    // (contagem e termo), e resultado que não aparece depois do retry.
    testWidgets('busca de clientes: erro com EstadoErro; "Tentar novamente" busca de novo e mostra o resultado',
        (tester) async {
      final termos = <String>[];
      await abrirTela(tester, TelaF4.formAdmin, estado: EstadoF4.erro, buscaClientes: (termo) async {
        termos.add(termo);
        if (termos.length == 1) throw semConexao;
        return const [ClienteResumo(id: 77, nome: 'Marcos', cpf: '***.***.***-25')];
      });
      await tester.enterText(find.byKey(const Key('campo-busca-cliente')), 'mar');
      await tocarVisivel(tester, find.byKey(const Key('botao-buscar-cliente')));
      final erro = find.byKey(const Key('form-erro-clientes'));
      expect(erro, findsOneWidget);
      expect(tester.widget(erro), isA<EstadoErro>());
      expect(find.descendant(of: erro, matching: find.textContaining('conex')), findsWidgets);
      expect(find.byKey(const Key('form-cliente-77')), findsNothing);
      expect(termos, ['mar']);
      await tocarVisivel(tester, find.descendant(of: erro, matching: find.text('Tentar novamente')));
      expect(termos, ['mar', 'mar']);
      expect(find.byKey(const Key('form-erro-clientes')), findsNothing);
      expect(find.byKey(const Key('form-cliente-77')), findsOneWidget);
      // o cliente recarregado é selecionável
      await tocarVisivel(tester, find.byKey(const Key('form-cliente-77')));
      expect(tester.widget<ListTile>(find.byKey(const Key('form-cliente-77'))).selected, isTrue);
    });

    // Volta 5 (tester): o retry usa o texto que está no campo NA HORA do toque (dev.md volta 5:
    // onTentarNovamente = () => c.buscarClientes(_busca.text)). Pega um retry com termo fixo/antigo.
    testWidgets('busca de clientes: "Tentar novamente" usa o texto atual do campo', (tester) async {
      final termos = <String>[];
      await abrirTela(tester, TelaF4.formAdmin, estado: EstadoF4.erro, buscaClientes: (termo) async {
        termos.add(termo);
        if (termos.length == 1) throw semConexao;
        return const [];
      });
      await tester.enterText(find.byKey(const Key('campo-busca-cliente')), 'ana');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(tester.widget(find.byKey(const Key('form-erro-clientes'))), isA<EstadoErro>());
      await tester.enterText(find.byKey(const Key('campo-busca-cliente')), 'bruno');
      await tester.pump();
      expect(termos, ['ana'], reason: 'digitar não dispara busca');
      await tocarVisivel(tester,
          find.descendant(of: find.byKey(const Key('form-erro-clientes')), matching: find.text('Tentar novamente')));
      expect(termos, ['ana', 'bruno']);
      expect(find.byKey(const Key('form-erro-clientes')), findsNothing);
      expect(tester.widget(find.byKey(const Key('form-clientes-vazio'))), isA<EstadoVazio>());
    });

    testWidgets('buscando mostra EstadoCarregando; ao terminar some', (tester) async {
      final c = Completer<List<ClienteResumo>>();
      await abrirTela(tester, TelaF4.formAdmin, estado: EstadoF4.erro, buscaClientes: (_) => c.future);
      expect(find.byType(EstadoCarregando), findsNothing);
      await tester.enterText(find.byKey(const Key('campo-busca-cliente')), 'mar');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(find.byType(EstadoCarregando), findsOneWidget);
      c.complete(const [ClienteResumo(id: 77, nome: 'Marcos')]);
      await tester.pumpAndSettle();
      expect(find.byType(EstadoCarregando), findsNothing);
      expect(find.byKey(const Key('form-cliente-77')), findsOneWidget);
    });
  });
}
