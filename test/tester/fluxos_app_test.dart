// Testes do TESTER (FASE 2): o app inteiro (router real + APIs reais + um único ApiClient)
// com o HTTP falso no lugar do backend. Cobre 401 global no meio do fluxo, login que falha
// não navega, 409 recarrega horários, cadastro com erros por campo e redirects por deep link.
import 'package:cortecerto_flutter/app.dart';
import 'package:cortecerto_flutter/core/network/api_client.dart';
import 'package:cortecerto_flutter/core/session/session_controller.dart';
import 'package:cortecerto_flutter/features/admin/data/admin_agendamento_api.dart';
import 'package:cortecerto_flutter/features/admin/data/clientes_api.dart';
import 'package:cortecerto_flutter/features/agendamento/data/agendamento_api.dart';
import 'package:cortecerto_flutter/features/agendamento/presentation/agendamento_controller.dart';
import 'package:cortecerto_flutter/features/agendamento/presentation/agendamento_page.dart';
import 'package:cortecerto_flutter/features/auth/data/auth_api.dart';
import 'package:cortecerto_flutter/features/servicos/data/servicos_api.dart';
import 'package:cortecerto_flutter/features/servicos/domain/servico.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import '../helpers/fakes.dart';

const _servicosJson = [
  {'id': 1, 'tipoServico': 'Corte Simples', 'descricao': 'Básico', 'precoServico': '35.00'},
  {'id': 2, 'tipoServico': 'Barba', 'descricao': 'Barba', 'precoServico': '25.00'},
];

/// "Backend" falso, configurável por teste.
class Backend {
  int loginStatus = 200;
  String loginRole = 'CLIENTE';
  int servicosStatus = 200;
  int dispStatus = 200;
  List<String> Function(int chamada) horarios = (_) => ['09:00', '09:30'];
  int agendarStatus = 200;
  int registerStatus = 200;
  Map<String, dynamic> registerBody = const {};
  int dispChamadas = 0;

  ResponseBody responder(RequestOptions o) {
    final p = o.path;
    if (p.endsWith('/clientes/login')) {
      if (loginStatus != 200) return jsonResponse({'status': loginStatus, 'message': 'x'}, loginStatus);
      return jsonResponse({
        'token': criarJwt(role: loginRole, name: 'Maria'),
        'id': 3,
        'name': 'Maria',
        'role': loginRole
      }, 200);
    }
    if (p.endsWith('/clientes/register')) {
      return jsonResponse(registerStatus == 200 ? null : registerBody, registerStatus);
    }
    if (p.endsWith('/servicos')) {
      return servicosStatus == 200
          ? jsonResponse(_servicosJson, 200)
          : jsonResponse({'status': servicosStatus, 'message': 'x'}, servicosStatus);
    }
    if (p.endsWith('/agendamento/disponibilidades')) {
      dispChamadas++;
      return dispStatus == 200
          ? jsonResponse(horarios(dispChamadas), 200)
          : jsonResponse({'status': dispStatus, 'message': 'x'}, dispStatus);
    }
    if (p.endsWith('/agendamento')) {
      return agendarStatus == 200
          ? jsonResponse({'id': 1}, 200)
          : jsonResponse({'status': agendarStatus, 'message': 'Mensagem do backend $agendarStatus'},
              agendarStatus);
    }
    return jsonResponse({'status': 404}, 404);
  }
}

void main() {
  late Backend backend;
  late FakeTokenStorage storage;
  late SessionController session;
  late FakeHttpAdapter adapter;

  setUpAll(() async => initializeDateFormatting('pt_BR'));

  setUp(() => backend = Backend());

  Future<void> abrir(WidgetTester tester, {String? token, String? local}) async {
    storage = FakeTokenStorage(token);
    session = SessionController(storage);
    await session.restaurar();
    adapter = FakeHttpAdapter(backend.responder);
    // Mesmo grafo do AppDependencies.criar: um ApiClient, 401 → session.expirar.
    final client = ApiClient(
      tokenStorage: storage,
      onUnauthorized: session.expirar,
      baseUrl: 'http://teste/api',
      httpClientAdapter: adapter,
    );
    await tester.pumpWidget(CorteCertoApp(
      deps: AppDependencies(
        session: session,
        authApi: AuthApi(client),
        servicosApi: ServicosApi(client),
        agendamentoApi: AgendamentoApi(client),
        adminAgendamentoApi: AdminAgendamentoApi(client),
        clientesApi: ClientesApi(client),
      ),
      localInicial: local,
    ));
    await tester.pumpAndSettle();
  }

  Future<void> logar(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('campo-cpf')), '52998224725');
    await tester.enterText(find.byKey(const Key('campo-senha')), 'abc12345');
    await tester.tap(find.byKey(const Key('botao-entrar')));
    await tester.pumpAndSettle();
  }

  /// Toca no dia de HOJE no calendário (primeiro dia habilitado).
  Future<void> tocarHoje(WidgetTester tester) async {
    final d = DateTime.now().day;
    final f = find.descendant(of: find.byKey(const Key('calendario')), matching: find.text('$d'));
    // Dias do mês anterior (>= 23) aparecem antes; dias do próximo mês (<= 13) depois.
    await tester.tap(d <= 22 ? f.first : f.last);
    await tester.pumpAndSettle();
  }

  Future<void> irParaAgendamento(WidgetTester tester) async {
    await abrir(tester, token: criarJwt(name: 'Maria'));
    expect(find.text('Olá, Maria!'), findsOneWidget);
    await tester.tap(find.text('Corte Simples'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendario')), findsOneWidget);
  }

  group('Login (app inteiro)', () {
    testWidgets('401 do login: fica no Login, "CPF ou senha inválidos", sem "Sessão expirada"',
        (tester) async {
      backend.loginStatus = 401;
      await abrir(tester);
      await logar(tester);
      expect(find.text('Bem-vindo'), findsOneWidget);
      expect(find.text('CPF ou senha inválidos'), findsOneWidget);
      expect(find.text('Sessão expirada, faça login novamente'), findsNothing);
      expect(find.text('Serviços'), findsNothing);
      expect(storage.token, isNull);
      expect(adapter.requisicoes.single.headers.containsKey('Authorization'), isFalse);
    });

    for (final (status, trecho) in [(423, 'bloqueada'), (429, 'Muitas tentativas'), (500, 'servidor')]) {
      testWidgets('login $status: fica no Login com mensagem', (tester) async {
        backend.loginStatus = status;
        await abrir(tester);
        await logar(tester);
        expect(find.text('Bem-vindo'), findsOneWidget);
        expect(find.textContaining(trecho), findsOneWidget);
        expect(session.isAutenticado, isFalse);
      });
    }

    testWidgets('sucesso salva o token na chave única e vai para Serviços', (tester) async {
      await abrir(tester);
      await logar(tester);
      expect(find.text('Olá, Maria!'), findsOneWidget);
      expect(storage.token, isNotNull);
      // a chamada de /servicos já leva o Bearer salvo
      final servicos = adapter.requisicoes.firstWhere((r) => r.path.endsWith('/servicos'));
      expect(servicos.headers['Authorization'], 'Bearer ${storage.token}');
    });

    testWidgets('ADMIN logando vai para o Painel Admin; sair volta ao Login', (tester) async {
      backend.loginRole = 'ADMIN';
      await abrir(tester);
      await logar(tester);
      expect(find.text('Painel Admin'), findsOneWidget);
      await tester.tap(find.byKey(const Key('botao-sair-admin')));
      await tester.pumpAndSettle();
      expect(find.text('Bem-vindo'), findsOneWidget);
      expect(storage.token, isNull);
    });
  });

  group('Cadastro (app inteiro)', () {
    Future<void> preencher(WidgetTester tester) async {
      await tester.enterText(find.byKey(const Key('campo-nome')), 'Maria Silva');
      await tester.enterText(find.byKey(const Key('campo-telefone')), '11987654321');
      await tester.enterText(find.byKey(const Key('campo-cpf')), '52998224725');
      await tester.enterText(find.byKey(const Key('campo-email')), 'maria@mail.com');
      await tester.enterText(find.byKey(const Key('campo-dataNascimento')), '15031990');
      await tester.enterText(find.byKey(const Key('campo-senha')), 'abc12345');
      await tester.enterText(find.byKey(const Key('campo-confirmarSenha')), 'abc12345');
      await tester.ensureVisible(find.byKey(const Key('botao-cadastrar')));
      await tester.tap(find.byKey(const Key('botao-cadastrar')));
      await tester.pumpAndSettle();
    }

    testWidgets('400 do backend aparece EMBAIXO do campo certo e some ao editar', (tester) async {
      backend.registerStatus = 400;
      backend.registerBody = {
        'status': 400,
        'message': 'cpf: CPF inválido no servidor; email: E-mail inválido no servidor',
        'errors': {'cpf': 'CPF inválido no servidor', 'email': 'E-mail inválido no servidor'}
      };
      await abrir(tester, local: '/cadastro');
      await preencher(tester);
      expect(
          find.descendant(
              of: find.byKey(const Key('campo-cpf')), matching: find.text('CPF inválido no servidor')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const Key('campo-email')),
              matching: find.text('E-mail inválido no servidor')),
          findsOneWidget);
      await tester.enterText(find.byKey(const Key('campo-cpf')), '11144477735');
      await tester.pump();
      expect(find.text('CPF inválido no servidor'), findsNothing);
      expect(find.text('E-mail inválido no servidor'), findsOneWidget);
    });

    testWidgets('409 mostra "CPF ou e-mail já cadastrado" e fica no Cadastro', (tester) async {
      backend.registerStatus = 409;
      backend.registerBody = {'status': 409, 'message': 'CPF já cadastrado'};
      await abrir(tester, local: '/cadastro');
      await preencher(tester);
      expect(find.text('CPF ou e-mail já cadastrado'), findsOneWidget);
      expect(find.text('Bem-vindo'), findsNothing);
    });

    testWidgets('Login → link Cadastro → sucesso → Login com "Cadastro realizado"', (tester) async {
      await abrir(tester);
      await tester.tap(find.byKey(const Key('link-cadastro')));
      await tester.pumpAndSettle();
      expect(find.text('Cadastro'), findsWidgets);
      await preencher(tester);
      expect(find.text('Bem-vindo'), findsOneWidget);
      expect(find.textContaining('Cadastro realizado'), findsOneWidget);
    });
  });

  group('401 global no meio do fluxo', () {
    testWidgets('401 em disponibilidades → Login com aviso, token apagado, sem exceção',
        (tester) async {
      backend.dispStatus = 401;
      await irParaAgendamento(tester);
      await tocarHoje(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Bem-vindo'), findsOneWidget);
      expect(find.text('Sessão expirada, faça login novamente'), findsOneWidget);
      expect(storage.token, isNull);
    });

    testWidgets('401 ao confirmar o agendamento → Login com aviso, sem exceção', (tester) async {
      backend.agendarStatus = 401;
      await irParaAgendamento(tester);
      await tocarHoje(tester);
      await tester.ensureVisible(find.text('09:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('09:00'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('botao-confirmar')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Sessão expirada, faça login novamente'), findsOneWidget);
      expect(storage.token, isNull);
    });

    testWidgets('depois do 401, logar de novo funciona e o aviso some', (tester) async {
      backend.servicosStatus = 401;
      await abrir(tester, token: criarJwt());
      expect(find.text('Sessão expirada, faça login novamente'), findsOneWidget);
      backend.servicosStatus = 200;
      await logar(tester);
      expect(find.text('Olá, Maria!'), findsOneWidget);
      expect(session.mensagem, isNull);
    });
  });

  group('Agendamento (app inteiro)', () {
    testWidgets('hoje: mostra exatamente os horários devolvidos pelo backend', (tester) async {
      backend.horarios = (_) => ['17:30'];
      await irParaAgendamento(tester);
      await tocarHoje(tester);
      final req = adapter.requisicoes.lastWhere((r) => r.path.endsWith('/disponibilidades'));
      final hoje = DateTime.now();
      expect(req.queryParameters['data'],
          '${hoje.year.toString().padLeft(4, '0')}-${hoje.month.toString().padLeft(2, '0')}-${hoje.day.toString().padLeft(2, '0')}');
      expect(find.text('17:30'), findsOneWidget);
      expect(find.text('09:00'), findsNothing);
    });

    testWidgets('409 → aviso e NOVA chamada de disponibilidades (horário some)', (tester) async {
      backend.agendarStatus = 409;
      backend.horarios = (n) => n == 1 ? ['09:00', '09:30'] : ['09:30'];
      await irParaAgendamento(tester);
      await tocarHoje(tester);
      await tester.ensureVisible(find.text('09:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('09:00'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('botao-confirmar')));
      await tester.pumpAndSettle();
      expect(backend.dispChamadas, 2);
      expect(find.textContaining('Horário acabou de ser reservado'), findsOneWidget);
      expect(find.text('09:00'), findsNothing);
      expect(find.text('09:30'), findsOneWidget);
      expect(session.isAutenticado, isTrue);
    });

    testWidgets('400 → mensagem do backend e continua no Agendamento', (tester) async {
      backend.agendarStatus = 400;
      await irParaAgendamento(tester);
      await tocarHoje(tester);
      await tester.ensureVisible(find.text('09:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('09:00'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('botao-confirmar')));
      await tester.pumpAndSettle();
      expect(find.text('Mensagem do backend 400'), findsOneWidget);
      expect(find.byKey(const Key('calendario')), findsOneWidget);
    });

    testWidgets('sucesso → Confirmado (dd/MM/aaaa) → Voltar aos serviços (não vai ao Login)',
        (tester) async {
      await irParaAgendamento(tester);
      await tocarHoje(tester);
      await tester.ensureVisible(find.text('09:30'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('09:30'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('botao-confirmar')));
      await tester.pumpAndSettle();
      final h = DateTime.now();
      final data =
          '${h.day.toString().padLeft(2, '0')}/${h.month.toString().padLeft(2, '0')}/${h.year}';
      expect(find.text('Agendamento confirmado!'), findsOneWidget);
      expect(find.textContaining(data), findsOneWidget);
      expect(find.textContaining('Corte Simples'), findsOneWidget);
      expect(find.textContaining('09:30'), findsOneWidget);
      // espera "muito" tempo: não pode haver timer mandando para o Login (bug do app antigo)
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(find.text('Bem-vindo'), findsNothing);
      await tester.tap(find.byKey(const Key('botao-voltar-servicos')));
      await tester.pumpAndSettle();
      expect(find.text('Olá, Maria!'), findsOneWidget);
    });

    testWidgets('dia de ontem fica desabilitado (sem chamada à API) — data fixa', (tester) async {
      // Data fixa (15/01/2030): "ontem" (14) está sempre no mesmo mês, sem depender do relógio.
      storage = FakeTokenStorage(criarJwt(name: 'Maria'));
      session = SessionController(storage);
      await session.restaurar();
      adapter = FakeHttpAdapter(backend.responder);
      final client = ApiClient(
        tokenStorage: storage,
        onUnauthorized: session.expirar,
        baseUrl: 'http://teste/api',
        httpClientAdapter: adapter,
      );
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session),
          ChangeNotifierProvider(create: (_) => AgendamentoController(AgendamentoApi(client))),
        ],
        child: MaterialApp(
          home: AgendamentoPage(
            servico: const Servico(id: 1, tipoServico: 'Corte Simples'),
            hoje: DateTime(2030, 1, 15),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byKey(const Key('calendario')), matching: find.text('14')));
      await tester.pumpAndSettle();
      expect(backend.dispChamadas, 0);
      expect(find.byKey(const Key('horarios-escolha-dia')), findsOneWidget);
      // o dia fixo de "hoje" continua habilitado e chama a API
      await tester.tap(find.descendant(of: find.byKey(const Key('calendario')), matching: find.text('15')));
      await tester.pumpAndSettle();
      expect(backend.dispChamadas, 1);
    });
  });

  group('Rotas por deep link', () {
    testWidgets('/agendamento sem serviço → /servicos', (tester) async {
      await abrir(tester, token: criarJwt(name: 'Maria'), local: '/agendamento');
      expect(find.text('Olá, Maria!'), findsOneWidget);
    });

    testWidgets('/agendamento/confirmado sem resumo → /servicos', (tester) async {
      await abrir(tester, token: criarJwt(name: 'Maria'), local: '/agendamento/confirmado');
      expect(find.text('Olá, Maria!'), findsOneWidget);
    });

    testWidgets('logado abrindo /login vai para /servicos', (tester) async {
      await abrir(tester, token: criarJwt(name: 'Maria'), local: '/login');
      expect(find.text('Olá, Maria!'), findsOneWidget);
    });

    testWidgets('ADMIN abrindo /produtos ou /servicos → /admin', (tester) async {
      for (final l in ['/produtos', '/servicos']) {
        await abrir(tester, token: criarJwt(role: 'ADMIN'), local: l);
        expect(find.text('Painel Admin'), findsOneWidget, reason: l);
      }
    });

    testWidgets('sem sessão abrindo /admin, /produtos e rota desconhecida → /login', (tester) async {
      for (final l in ['/admin', '/produtos', '/agendamento', '/rota-que-nao-existe']) {
        await abrir(tester, local: l);
        expect(find.text('Bem-vindo'), findsOneWidget, reason: l);
      }
    });

    testWidgets('sem sessão pode abrir /cadastro', (tester) async {
      await abrir(tester, local: '/cadastro');
      expect(find.byKey(const Key('botao-cadastrar')), findsOneWidget);
    });

    testWidgets('Produtos acessível pelos Serviços e com logout', (tester) async {
      await abrir(tester, token: criarJwt());
      await tester.tap(find.byKey(const Key('botao-produtos')));
      await tester.pumpAndSettle();
      expect(find.text('Pomada'), findsOneWidget);
      expect(find.byKey(const Key('botao-sair')), findsOneWidget);
      await tester.tap(find.byKey(const Key('botao-sair')));
      await tester.pumpAndSettle();
      expect(find.text('Bem-vindo'), findsOneWidget);
      expect(storage.token, isNull);
    });

    testWidgets('logout disponível no Agendamento', (tester) async {
      await irParaAgendamento(tester);
      await tester.tap(find.byKey(const Key('botao-sair')));
      await tester.pumpAndSettle();
      expect(find.text('Bem-vindo'), findsOneWidget);
      expect(storage.token, isNull);
      expect(storage.clears, greaterThanOrEqualTo(1));
    });
  });
}
