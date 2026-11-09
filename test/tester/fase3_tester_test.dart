// FASE 3 (tester): contrato HTTP das APIs novas (Dio real + adapter falso), bordas da Agenda Admin,
// do formulário e de Meus Agendamentos, rotas com o app inteiro e checagens das pendências da seção 0.
import 'dart:async';
import 'dart:io';

import 'package:cortecerto_flutter/app.dart';
import 'package:cortecerto_flutter/core/errors/api_exception.dart';
import 'package:cortecerto_flutter/core/network/api_client.dart';
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
import 'package:cortecerto_flutter/features/meus_agendamentos/presentation/meus_agendamentos_page.dart';
import 'package:cortecerto_flutter/features/servicos/data/servicos_api.dart';
import 'package:cortecerto_flutter/features/servicos/domain/servico.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../helpers/fakes.dart';
import '../helpers/widget_helpers.dart';

const _servico = Servico(id: 1, tipoServico: 'Corte Simples', precoServico: '35.00');
const _barba = Servico(id: 2, tipoServico: 'Barba', precoServico: '25.00');
final _dia = DateTime(2030, 1, 15);

AgendamentoAdmin ag(int id, String horario, StatusAgendamento status, {String nome = 'Ana Souza', DateTime? data}) =>
    AgendamentoAdmin(
      id: id,
      data: data ?? _dia,
      horario: horario,
      status: status,
      servicoId: 1,
      servico: 'Corte Simples',
      clienteId: 50 + id,
      nomeCliente: nome,
      telefoneCliente: '11999990000',
    );

Future<void> tocar(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    registerFallbackValue(_servico);
    registerFallbackValue(DateTime(2030));
    registerFallbackValue(StatusAgendamento.pendente);
  });

  // ===================================================================== contrato HTTP das APIs
  group('APIs novas com Dio real (método, caminho, corpo, parse e erros)', () {
    late FakeHttpAdapter adapter;
    late ResponseBody Function(RequestOptions) responder;
    late ApiClient client;

    setUp(() {
      responder = (_) => jsonResponse(const [], 200);
      adapter = FakeHttpAdapter((o) => responder(o));
      client = ApiClient(
        tokenStorage: FakeTokenStorage('tok-admin'),
        baseUrl: 'http://api.teste/api',
        onUnauthorized: () async {},
        httpClientAdapter: adapter,
      );
    });

    final json = {
      'id': 7,
      'data': '2030-01-15',
      'horario': '09:30',
      'status': 'CONFIRMADO',
      'servicoId': 2,
      'servico': 'Barba',
      'clienteId': 40,
      'nomeCliente': 'Ana',
      'telefoneCliente': null,
    };

    test('listar: GET /agendamento/admin?data=AAAA-MM-DD[&status], com Bearer, parse tolera telefone null', () async {
      responder = (_) => jsonResponse([json], 200);
      final api = AdminAgendamentoApi(client);
      final lista = await api.listar(DateTime(2030, 1, 5, 23, 59));
      final r = adapter.requisicoes.single;
      expect(r.method, 'GET');
      expect(r.path, '/agendamento/admin');
      expect(r.queryParameters, {'data': '2030-01-05'});
      expect(r.headers['Authorization'], 'Bearer tok-admin');
      final a = lista.single;
      expect(a.id, 7);
      expect(a.data, DateTime(2030, 1, 15));
      expect(a.horario, '09:30');
      expect(a.status, StatusAgendamento.confirmado);
      expect(a.servicoId, 2);
      expect(a.servico, 'Barba');
      expect(a.clienteId, 40);
      expect(a.nomeCliente, 'Ana');
      expect(a.telefoneCliente, isNull);

      await api.listar(DateTime(2030, 1, 5), status: StatusAgendamento.cancelado);
      expect(adapter.requisicoes.last.queryParameters, {'data': '2030-01-05', 'status': 'CANCELADO'});
    });

    test('criar: POST com {clienteId, servicoId, data, horario, status?}; sem status não envia a chave', () async {
      responder = (_) => jsonResponse(json, 201);
      final api = AdminAgendamentoApi(client);
      final criado = await api.criar(clienteId: 40, servicoId: 2, data: DateTime(2030, 1, 15), horario: '09:30');
      expect(criado.id, 7);
      var r = adapter.requisicoes.last;
      expect(r.method, 'POST');
      expect(r.path, '/agendamento/admin');
      expect(r.data, {'clienteId': 40, 'servicoId': 2, 'data': '2030-01-15', 'horario': '09:30'});
      await api.criar(
          clienteId: 40, servicoId: 2, data: DateTime(2030, 1, 15), horario: '09:30', status: StatusAgendamento.pendente);
      r = adapter.requisicoes.last;
      expect((r.data as Map)['status'], 'PENDENTE');
    });

    test('atualizar: PUT /agendamento/admin/{id} só com os campos informados', () async {
      responder = (_) => jsonResponse(json, 200);
      final api = AdminAgendamentoApi(client);
      await api.atualizar(7, status: StatusAgendamento.realizado);
      var r = adapter.requisicoes.last;
      expect(r.method, 'PUT');
      expect(r.path, '/agendamento/admin/7');
      expect(r.data, {'status': 'REALIZADO'});
      await api.atualizar(7, servicoId: 3, data: DateTime(2030, 2, 1), horario: '10:00', status: StatusAgendamento.pendente);
      r = adapter.requisicoes.last;
      expect(r.data, {'servicoId': 3, 'data': '2030-02-01', 'horario': '10:00', 'status': 'PENDENTE'});
    });

    test('cancelar: PUT /agendamento/{id}/cancelar; excluir: DELETE /agendamento/admin/{id} com 204 vazio', () async {
      responder = (o) => o.method == 'DELETE' ? ResponseBody.fromString('', 204) : jsonResponse({'id': 7}, 200);
      final api = AdminAgendamentoApi(client);
      await api.cancelar(7);
      expect(adapter.requisicoes.last.method, 'PUT');
      expect(adapter.requisicoes.last.path, '/agendamento/7/cancelar');
      await api.excluir(7);
      expect(adapter.requisicoes.last.method, 'DELETE');
      expect(adapter.requisicoes.last.path, '/agendamento/admin/7');
    });

    test('erros: 409 → conflito com a mensagem do backend; 403 → proibido; 404 → não encontrado; 400 → dados', () async {
      final api = AdminAgendamentoApi(client);
      responder = (_) => jsonResponse({'status': 409, 'message': 'Horário indisponível'}, 409);
      await expectLater(
          api.criar(clienteId: 1, servicoId: 1, data: _dia, horario: '09:00'),
          throwsA(isA<ApiException>()
              .having((e) => e.tipo, 'tipo', ApiErrorTipo.conflito)
              .having((e) => e.mensagem, 'mensagem', 'Horário indisponível')));
      responder = (_) => jsonResponse({'status': 403, 'message': 'Acesso negado'}, 403);
      await expectLater(api.listar(_dia),
          throwsA(isA<ApiException>().having((e) => e.tipo, 'tipo', ApiErrorTipo.proibido)));
      responder = (_) => jsonResponse({'status': 404, 'message': 'Agendamento não encontrado'}, 404);
      await expectLater(api.excluir(1),
          throwsA(isA<ApiException>().having((e) => e.tipo, 'tipo', ApiErrorTipo.naoEncontrado)));
      responder = (_) => jsonResponse(
          {'status': 400, 'message': 'Não é possível agendar em data/horário passado'}, 400);
      await expectLater(api.atualizar(1, horario: '08:00'),
          throwsA(isA<ApiException>().having((e) => e.tipo, 'tipo', ApiErrorTipo.dadosInvalidos)));
    });

    test('ClientesApi.buscar: GET /clientes?busca=<termo aparado>; parse com CPF mascarado', () async {
      responder = (_) => jsonResponse([
            {'id': 5, 'nome': 'Ana', 'cpf': '***.***.***-25', 'telefone': null},
          ], 200);
      final lista = await ClientesApi(client).buscar('  ana  ');
      final r = adapter.requisicoes.single;
      expect(r.method, 'GET');
      expect(r.path, '/clientes');
      expect(r.queryParameters, {'busca': 'ana'});
      expect(lista.single.cpf, '***.***.***-25');
      expect(lista.single.telefone, isNull);
    });

    test('AgendamentoApi.meus: GET /agendamento/meus; cancelar: PUT /agendamento/{id}/cancelar', () async {
      responder = (o) => o.path.endsWith('/meus')
          ? jsonResponse([
              {'id': 3, 'data': '2030-01-20', 'horario': '14:00', 'status': 'CANCELADO', 'servico': 'Barba'},
            ], 200)
          : jsonResponse({'id': 3}, 200);
      final api = AgendamentoApi(client);
      final meus = await api.meus();
      expect(adapter.requisicoes.last.method, 'GET');
      expect(adapter.requisicoes.last.path, '/agendamento/meus');
      expect(meus.single.status, StatusAgendamento.cancelado);
      expect(meus.single.dataHoraInicio, DateTime(2030, 1, 20, 14));
      await api.cancelar(3);
      expect(adapter.requisicoes.last.method, 'PUT');
      expect(adapter.requisicoes.last.path, '/agendamento/3/cancelar');
    });

    test('nenhuma requisição usa cache: duas chamadas a meus() batem duas vezes no servidor', () async {
      responder = (_) => jsonResponse(const [], 200);
      final api = AgendamentoApi(client);
      await api.meus();
      await api.meus();
      expect(adapter.requisicoes.where((r) => r.path == '/agendamento/meus'), hasLength(2));
    });
  });

  // ===================================================================== Agenda Admin
  group('Agenda Admin (bordas)', () {
    late SessionController session;
    late MockAdminAgendamentoApi api;
    late MockClientesApi clientesApi;
    late MockAgendamentoApi agendamentoApi;
    late MockServicosApi servicosApi;
    late List<AgendamentoAdmin> doDia;

    setUp(() async {
      session = SessionController(FakeTokenStorage());
      await session.iniciar('t', const Usuario(id: 9, nome: 'Chefe', role: 'ADMIN'));
      api = MockAdminAgendamentoApi();
      clientesApi = MockClientesApi();
      agendamentoApi = MockAgendamentoApi();
      servicosApi = MockServicosApi();
      doDia = [
        ag(1, '09:00', StatusAgendamento.pendente, nome: 'Ana Souza'),
        ag(2, '10:00', StatusAgendamento.confirmado, nome: 'Bruno Lima'),
        ag(3, '10:00', StatusAgendamento.cancelado, nome: 'Carlos Dias'),
        ag(4, '11:00', StatusAgendamento.realizado, nome: 'Dani Rocha'),
        ag(5, '12:00', StatusAgendamento.cancelado, nome: 'Edu Prado'),
        ag(6, '13:00', StatusAgendamento.confirmado, nome: 'Ana Lima'),
      ];
      when(() => api.listar(any())).thenAnswer((_) async => doDia);
      when(() => servicosApi.listar()).thenAnswer((_) async => const [_servico, _barba]);
      when(() => agendamentoApi.disponibilidades(any())).thenAnswer((_) async => ['12:00', '12:30']);
    });

    Widget montar() {
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => ChangeNotifierProvider(
            create: (_) => AgendaAdminController(api, relogio: () => DateTime(2030, 1, 15, 8)),
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
            ),
            child: const AgendamentoFormPage(),
          ),
        ),
      ]);
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session),
          Provider<AdminAgendamentoApi>.value(value: api),
          Provider<ClientesApi>.value(value: clientesApi),
          Provider<AgendamentoApi>.value(value: agendamentoApi),
          Provider<ServicosApi>.value(value: servicosApi),
        ],
        child: MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
      );
    }

    Future<void> abrir(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();
    }

    Finder em(String horario, Finder f) => find.descendant(of: find.byKey(Key('agenda-horario-$horario')), matching: f);

    testWidgets('horário só com cancelado aparece Disponível com a nota e abre o formulário de criar nele',
        (tester) async {
      await abrir(tester);
      expect(em('12:00', find.text('Disponível')), findsOneWidget);
      expect(em('12:00', find.text('1 cancelado neste horário')), findsOneWidget);
      expect(find.text('Edu Prado'), findsNothing);
      // 10:00 tem ativo + cancelado: mostra o ativo
      expect(em('10:00', find.text('Bruno Lima')), findsOneWidget);
      expect(em('10:00', find.text('Disponível')), findsNothing);
      await tocar(tester, find.byKey(const Key('agenda-horario-12:00')));
      expect(find.text('Novo agendamento'), findsOneWidget);
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('form-horario-12:00'))).selected, isTrue);
    });

    testWidgets('contadores contam o dia inteiro e não mudam com filtro/busca; filtro vira lista sem "Disponível"',
        (tester) async {
      await abrir(tester);
      String valor(String k) => tester.widget<Text>(find.byKey(Key('contador-$k-valor'))).data!;
      void conferir() {
        expect(valor('total'), '6');
        expect(valor('PENDENTE'), '1');
        expect(valor('CONFIRMADO'), '2');
        expect(valor('CANCELADO'), '2');
        expect(valor('REALIZADO'), '1');
      }

      conferir();
      await tocar(tester, find.byKey(const Key('filtro-CONFIRMADO')));
      await tester.enterText(find.byKey(const Key('campo-busca-agenda')), 'ANA');
      await tester.pumpAndSettle();
      conferir();
      expect(find.byKey(const Key('agendamento-6')), findsOneWidget);
      expect(find.byKey(const Key('agendamento-1')), findsNothing); // Ana Souza é PENDENTE
      expect(find.byKey(const Key('agendamento-2')), findsNothing); // Bruno não casa com "ana"
      expect(find.text('Disponível'), findsNothing);
      expect(find.byKey(const Key('agenda-horario-08:00')), findsNothing);
      // tocar no mesmo chip desmarca o filtro; com busca vazia volta a grade
      await tocar(tester, find.byKey(const Key('filtro-CONFIRMADO')));
      expect(find.byKey(const Key('agendamento-1')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('campo-busca-agenda')), '   ');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('agenda-horario-08:00')), findsOneWidget);
      // filtro CANCELADO mostra os cancelados que a grade esconde (inclusive o do horário com ativo)
      await tocar(tester, find.byKey(const Key('filtro-CANCELADO')));
      expect(find.text('Carlos Dias'), findsOneWidget);
      expect(find.text('Edu Prado'), findsOneWidget);
      expect(find.text('Bruno Lima'), findsNothing);
    });

    testWidgets('"Data" abre o calendário, busca o dia escolhido no servidor e "Hoje" volta', (tester) async {
      await abrir(tester);
      clearInteractions(api);
      await tocar(tester, find.byKey(const Key('periodo-data')));
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      verify(() => api.listar(DateTime(2030, 1, 20))).called(1);
      expect(find.text('Agenda - 20/01/2030'), findsOneWidget);
      await tocar(tester, find.byKey(const Key('periodo-hoje')));
      verify(() => api.listar(_dia)).called(1);
      expect(find.text('Agenda - Hoje'), findsOneWidget);
    });

    testWidgets('troca de dia descarta a resposta atrasada do dia anterior', (tester) async {
      final lento = Completer<List<AgendamentoAdmin>>();
      when(() => api.listar(_dia)).thenAnswer((_) => lento.future);
      when(() => api.listar(DateTime(2030, 1, 16)))
          .thenAnswer((_) async => [ag(9, '15:00', StatusAgendamento.pendente, nome: 'Zeca Amanhã')]);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(montar());
      await tester.pump();
      await tester.tap(find.byKey(const Key('periodo-amanha')));
      await tester.pumpAndSettle();
      lento.complete([ag(1, '15:00', StatusAgendamento.pendente, nome: 'Velho de Hoje')]);
      await tester.pumpAndSettle();
      expect(find.text('Agenda - Amanhã'), findsOneWidget);
      expect(find.text('Zeca Amanhã'), findsOneWidget);
      expect(find.text('Velho de Hoje'), findsNothing);
    });

    testWidgets('detalhes: ações conforme o status (CANCELADO não cancela; REALIZADO não confirma/realiza)',
        (tester) async {
      await abrir(tester);
      await tocar(tester, find.byKey(const Key('agenda-horario-11:00'))); // REALIZADO
      expect(find.byKey(const Key('detalhes-agendamento')), findsOneWidget);
      expect(find.byKey(const Key('acao-confirmar')), findsNothing);
      expect(find.byKey(const Key('acao-realizar')), findsNothing);
      expect(find.byKey(const Key('acao-cancelar')), findsOneWidget);
      expect(find.byKey(const Key('acao-excluir')), findsOneWidget);
      expect(find.byKey(const Key('acao-editar')), findsOneWidget);
      await tocar(tester, find.byKey(const Key('acao-fechar')));
      // a lista é preguiçosa: volta ao topo para os chips de filtro existirem de novo
      await tester.drag(find.byType(ListView).first, const Offset(0, 5000));
      await tester.pumpAndSettle();

      await tocar(tester, find.byKey(const Key('filtro-CANCELADO')));
      await tocar(tester, find.byKey(const Key('agendamento-3')));
      expect(find.byKey(const Key('acao-cancelar')), findsNothing);
      expect(find.byKey(const Key('acao-confirmar')), findsNothing);
      expect(find.byKey(const Key('acao-realizar')), findsNothing);
      expect(find.byKey(const Key('acao-excluir')), findsOneWidget);
      expect(find.byKey(const Key('detalhe-telefone')), findsOneWidget);
      expect(find.textContaining('11999990000'), findsOneWidget);
    });

    testWidgets('Excluir com "Voltar" não chama a API; erro 404 ao excluir mostra snack de erro e recarrega',
        (tester) async {
      when(() => api.excluir(any())).thenThrow(const ApiException(
          tipo: ApiErrorTipo.naoEncontrado, statusCode: 404, mensagem: 'Agendamento não encontrado'));
      await abrir(tester);
      await tocar(tester, find.byKey(const Key('agenda-horario-09:00')));
      await tocar(tester, find.byKey(const Key('acao-excluir')));
      expect(find.byType(AlertDialog), findsOneWidget);
      await tocar(tester, find.byKey(const Key('dialogo-nao')));
      verifyNever(() => api.excluir(any()));

      clearInteractions(api);
      await tocar(tester, find.byKey(const Key('agenda-horario-09:00')));
      await tocar(tester, find.byKey(const Key('acao-excluir')));
      await tocar(tester, find.byKey(const Key('dialogo-sim')));
      verify(() => api.excluir(1)).called(1);
      expect(find.byKey(const Key('snack-erro')), findsOneWidget);
      expect(find.text('Agendamento não encontrado'), findsOneWidget);
      verify(() => api.listar(_dia)).called(1);
    });

    testWidgets('Excluir com sucesso: o agendamento some da grade depois do recarregamento', (tester) async {
      when(() => api.excluir(any())).thenAnswer((_) async {
        doDia = doDia.where((a) => a.id != 1).toList();
      });
      await abrir(tester);
      expect(em('09:00', find.text('Ana Souza')), findsOneWidget);
      await tocar(tester, find.byKey(const Key('agenda-horario-09:00')));
      await tocar(tester, find.byKey(const Key('acao-excluir')));
      await tocar(tester, find.byKey(const Key('dialogo-sim')));
      expect(find.byKey(const Key('snack-sucesso')), findsOneWidget);
      expect(em('09:00', find.text('Disponível')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('contador-total-valor'))).data, '5');
    });

    testWidgets('Cancelar com sucesso: o horário passa a "Disponível" e o contador de cancelados sobe',
        (tester) async {
      when(() => api.cancelar(any())).thenAnswer((_) async {
        doDia = [
          for (final a in doDia)
            a.id == 6 ? ag(6, '13:00', StatusAgendamento.cancelado, nome: 'Ana Lima') : a,
        ];
      });
      await abrir(tester);
      await tocar(tester, find.byKey(const Key('agenda-horario-13:00')));
      await tocar(tester, find.byKey(const Key('acao-cancelar')));
      await tocar(tester, find.byKey(const Key('dialogo-sim')));
      verify(() => api.cancelar(6)).called(1);
      expect(em('13:00', find.text('Disponível')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('contador-CANCELADO-valor'))).data, '3');
    });

    testWidgets('editar: trocar a data busca os horários do novo dia; 409 ao salvar mostra o erro no formulário',
        (tester) async {
      // O calendário do formulário usa DateTime.now() (não injetável): datas relativas a hoje.
      final agora = DateTime.now();
      final perto = DateTime(agora.year, agora.month, agora.day).add(const Duration(days: 3));
      final alvo = perto.add(const Duration(days: 7));
      doDia = [ag(2, '10:00', StatusAgendamento.confirmado, nome: 'Bruno Lima', data: perto)];
      when(() => agendamentoApi.disponibilidades(alvo)).thenAnswer((_) async => ['16:00']);
      when(() => api.atualizar(any(),
              servicoId: any(named: 'servicoId'),
              data: any(named: 'data'),
              horario: any(named: 'horario'),
              status: any(named: 'status')))
          .thenThrow(const ApiException(tipo: ApiErrorTipo.conflito, statusCode: 409, mensagem: 'Horário indisponível'));
      await abrir(tester);
      await tocar(tester, find.byKey(const Key('agenda-horario-10:00')));
      await tocar(tester, find.byKey(const Key('acao-editar')));
      expect(find.text('Editar agendamento'), findsOneWidget);
      // na data original o próprio horário é oferecido (manter não é conflito)
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('form-horario-10:00'))).selected, isTrue);
      await tocar(tester, find.byKey(const Key('form-botao-data')));
      await tester.tap(find.byIcon(Icons.edit_outlined).last);
      await tester.pumpAndSettle();
      String dd(int n) => n.toString().padLeft(2, '0');
      await tester.enterText(
          find.descendant(of: find.byType(DatePickerDialog), matching: find.byType(TextField)),
          '${dd(alvo.month)}/${dd(alvo.day)}/${alvo.year}');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      verify(() => agendamentoApi.disponibilidades(alvo)).called(1);
      // no outro dia o horário antigo (10:00) não é oferecido
      expect(find.byKey(const Key('form-horario-10:00')), findsNothing);
      await tocar(tester, find.byKey(const Key('form-horario-16:00')));
      await tocar(tester, find.byKey(const Key('form-servico-2')));
      await tocar(tester, find.byKey(const Key('form-botao-salvar')));
      verify(() => api.atualizar(2,
          servicoId: 2, data: alvo, horario: '16:00', status: StatusAgendamento.confirmado)).called(1);
      expect(find.byKey(const Key('form-erro')), findsOneWidget);
      expect(find.text('Horário indisponível'), findsOneWidget);
      expect(find.text('Editar agendamento'), findsOneWidget);
    });

    testWidgets('ACHADO: editar agendamento a mais de 1 ano no futuro e abrir o calendário não pode quebrar',
        (tester) async {
      final agora = DateTime.now();
      final longe = DateTime(agora.year + 2, agora.month, 1);
      doDia = [ag(2, '10:00', StatusAgendamento.confirmado, nome: 'Bruno Lima', data: longe)];
      await abrir(tester);
      await tocar(tester, find.byKey(const Key('agenda-horario-10:00')));
      await tocar(tester, find.byKey(const Key('acao-editar')));
      await tester.ensureVisible(find.byKey(const Key('form-botao-data')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('form-botao-data')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(DatePickerDialog), findsOneWidget);
    }, skip: false);

    testWidgets('formulário de criar: sem cliente/serviço/horário o Salvar não envia nada', (tester) async {
      await abrir(tester);
      await tocar(tester, find.byKey(const Key('botao-novo-agendamento')));
      expect(find.text('Novo agendamento'), findsOneWidget);
      expect(find.byKey(const Key('form-status-CANCELADO')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('form-botao-salvar')));
      await tester.tap(find.byKey(const Key('form-botao-salvar')), warnIfMissed: false);
      await tester.pumpAndSettle();
      verifyNever(() => api.criar(
            clienteId: any(named: 'clienteId'),
            servicoId: any(named: 'servicoId'),
            data: any(named: 'data'),
            horario: any(named: 'horario'),
            status: any(named: 'status'),
          ));
    });

    testWidgets('formulário: busca de clientes sem resultado e com erro são mostradas', (tester) async {
      when(() => clientesApi.buscar('zzz')).thenAnswer((_) async => const []);
      when(() => clientesApi.buscar('erro')).thenThrow(
          const ApiException(tipo: ApiErrorTipo.semConexao, mensagem: 'Sem conexão com o servidor'));
      await abrir(tester);
      await tocar(tester, find.byKey(const Key('botao-novo-agendamento')));
      await tester.enterText(find.byKey(const Key('campo-busca-cliente')), 'zzz');
      await tocar(tester, find.byKey(const Key('botao-buscar-cliente')));
      expect(find.byKey(const Key('form-clientes-vazio')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('campo-busca-cliente')), 'erro');
      await tocar(tester, find.byKey(const Key('botao-buscar-cliente')));
      expect(find.byKey(const Key('form-erro-clientes')), findsOneWidget);
    });
  });

  // ===================================================================== controllers: dispose no meio
  group('Controllers novos: resposta depois do dispose não lança', () {
    test('AgendaAdminController.carregar', () async {
      final api = MockAdminAgendamentoApi();
      final c = Completer<List<AgendamentoAdmin>>();
      when(() => api.listar(any())).thenAnswer((_) => c.future);
      final ctrl = AgendaAdminController(api);
      final f = ctrl.carregar();
      ctrl.dispose();
      c.complete(const []);
      await expectLater(f, completes);
    });

    test('AgendaAdminController: ação terminando depois do dispose não recarrega', () async {
      final api = MockAdminAgendamentoApi();
      final c = Completer<void>();
      when(() => api.excluir(any())).thenAnswer((_) => c.future);
      final ctrl = AgendaAdminController(api);
      final f = ctrl.excluir(ag(1, '09:00', StatusAgendamento.pendente));
      ctrl.dispose();
      c.complete();
      expect((await f).sucesso, isTrue);
      verifyNever(() => api.listar(any()));
    });

    test('MeusAgendamentosController.carregar e cancelar', () async {
      final api = MockAgendamentoApi();
      final c = Completer<List<MeuAgendamento>>();
      when(() => api.meus()).thenAnswer((_) => c.future);
      final ctrl = MeusAgendamentosController(api);
      final f = ctrl.carregar();
      ctrl.dispose();
      c.complete(const []);
      await expectLater(f, completes);
    });

    test('AgendamentoFormController.iniciar', () async {
      final servicos = MockServicosApi();
      final agenda = MockAgendamentoApi();
      final s = Completer<List<Servico>>();
      final h = Completer<List<String>>();
      when(() => servicos.listar()).thenAnswer((_) => s.future);
      when(() => agenda.disponibilidades(any())).thenAnswer((_) => h.future);
      final ctrl = AgendamentoFormController(
        adminApi: MockAdminAgendamentoApi(),
        clientesApi: MockClientesApi(),
        agendamentoApi: agenda,
        servicosApi: servicos,
        args: AgendamentoFormArgs.criar(data: _dia),
      );
      final f = ctrl.iniciar();
      ctrl.dispose();
      s.complete(const [_servico]);
      h.complete(['09:00']);
      await expectLater(f, completes);
    });
  });

  // ===================================================================== Meus Agendamentos
  group('Meus Agendamentos (bordas)', () {
    late SessionController session;
    late MockAgendamentoApi api;
    final agora = DateTime(2030, 1, 15, 10);

    setUp(() async {
      session = SessionController(FakeTokenStorage());
      await session.iniciar('t', const Usuario(id: 3, nome: 'Maria', role: 'CLIENTE'));
      api = MockAgendamentoApi();
    });

    Widget montar() => comRouter(const MeusAgendamentosPage(), providers: [
          ChangeNotifierProvider<SessionController>.value(value: session),
          ChangeNotifierProvider(create: (_) => MeusAgendamentosController(api, relogio: () => agora)),
        ]);

    testWidgets('erro ao carregar mostra a mensagem e "Tentar novamente" busca de novo', (tester) async {
      var falhar = true;
      when(() => api.meus()).thenAnswer((_) async {
        if (falhar) throw const ApiException(tipo: ApiErrorTipo.semConexao, mensagem: 'Sem conexão com o servidor');
        return [MeuAgendamento(id: 1, data: DateTime(2030, 1, 20), horario: '09:00', status: StatusAgendamento.pendente, servico: 'Barba')];
      });
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('meus-erro')), findsOneWidget);
      falhar = false;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('Barba'), findsOneWidget);
      verify(() => api.meus()).called(2);
    });

    testWidgets('agendamento de hoje que já passou fica no Histórico sem botão de cancelar', (tester) async {
      when(() => api.meus()).thenAnswer((_) async => [
            MeuAgendamento(id: 1, data: DateTime(2030, 1, 15), horario: '09:30', status: StatusAgendamento.confirmado, servico: 'Barba'),
            MeuAgendamento(id: 2, data: DateTime(2030, 1, 15), horario: '10:30', status: StatusAgendamento.confirmado, servico: 'Corte'),
          ]);
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();
      expect(find.text('Próximos (1)'), findsOneWidget);
      expect(find.byKey(const Key('botao-cancelar-2')), findsOneWidget);
      expect(find.byKey(const Key('botao-cancelar-1')), findsNothing);
      await tester.tap(find.byKey(const Key('aba-historico')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('meu-agendamento-1')), findsOneWidget);
      expect(find.byKey(const Key('botao-cancelar-1')), findsNothing);
    });

    testWidgets('pull-to-refresh na aba Histórico também busca no servidor', (tester) async {
      when(() => api.meus()).thenAnswer((_) async => [
            MeuAgendamento(id: 2, data: DateTime(2030, 1, 10), horario: '09:00', status: StatusAgendamento.realizado, servico: 'Corte'),
          ]);
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('aba-historico')));
      await tester.pumpAndSettle();
      await tester.fling(find.byKey(const Key('lista-historico')), const Offset(0, 600), 1500);
      await tester.pumpAndSettle();
      verify(() => api.meus()).called(2);
    });

    testWidgets('pausar sem voltar não recarrega; só o retorno ao primeiro plano', (tester) async {
      when(() => api.meus()).thenAnswer((_) async => const []);
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();
      for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pumpAndSettle();
      verify(() => api.meus()).called(1);
      for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
      await tester.pumpAndSettle();
      verify(() => api.meus()).called(1);
    });

    testWidgets('cancelar com erro 409 (já cancelado) mostra a mensagem e recarrega a lista', (tester) async {
      when(() => api.meus()).thenAnswer((_) async => [
            MeuAgendamento(id: 1, data: DateTime(2030, 1, 20), horario: '09:00', status: StatusAgendamento.confirmado, servico: 'Barba'),
          ]);
      when(() => api.cancelar(1)).thenThrow(const ApiException(
          tipo: ApiErrorTipo.conflito, statusCode: 409, mensagem: 'Agendamento já está cancelado'));
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('botao-cancelar-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dialogo-sim')));
      await tester.pumpAndSettle();
      expect(find.text('Agendamento já está cancelado'), findsOneWidget);
      verify(() => api.meus()).called(2);
    });
  });

  // ===================================================================== app inteiro: sem cache entre aberturas
  group('App inteiro', () {
    testWidgets('CLIENTE abre Meus duas vezes: cada abertura busca no servidor e mostra o dado novo', (tester) async {
      final agendamentoApi = MockAgendamentoApi();
      final servicosApi = MockServicosApi();
      when(() => servicosApi.listar()).thenAnswer((_) async => const [_servico]);
      var lista = [
        MeuAgendamento(id: 1, data: DateTime(2099, 1, 20), horario: '09:00', status: StatusAgendamento.confirmado, servico: 'Barba'),
      ];
      when(() => agendamentoApi.meus()).thenAnswer((_) async => lista);
      final session = SessionController(FakeTokenStorage(criarJwt(name: 'Maria')));
      await session.restaurar();
      await tester.pumpWidget(CorteCertoApp(
        deps: AppDependencies(
          session: session,
          authApi: MockAuthApi(),
          servicosApi: servicosApi,
          agendamentoApi: agendamentoApi,
          adminAgendamentoApi: MockAdminAgendamentoApi(),
          clientesApi: MockClientesApi(),
        ),
        localInicial: Rotas.servicos,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('botao-meus-agendamentos')));
      await tester.pumpAndSettle();
      expect(find.text('Confirmado'), findsOneWidget);
      await tester.tap(find.byKey(const Key('botao-voltar')));
      await tester.pumpAndSettle();
      // o admin muda o agendamento no servidor
      lista = [
        MeuAgendamento(id: 1, data: DateTime(2099, 1, 20), horario: '11:30', status: StatusAgendamento.pendente, servico: 'Barba'),
      ];
      await tester.tap(find.byKey(const Key('botao-meus-agendamentos')));
      await tester.pumpAndSettle();
      expect(find.text('Pendente'), findsOneWidget);
      expect(find.textContaining('11:30'), findsOneWidget);
      verify(() => agendamentoApi.meus()).called(2);
    });

    testWidgets('sessão expirada (401) em /admin/agenda leva ao login', (tester) async {
      final adminApi = MockAdminAgendamentoApi();
      final storage = FakeTokenStorage(criarJwt(role: 'ADMIN'));
      final session = SessionController(storage);
      await session.restaurar();
      when(() => adminApi.listar(any())).thenAnswer((_) async {
        await session.expirar();
        throw const ApiException(tipo: ApiErrorTipo.naoAutorizado, statusCode: 401, mensagem: 'Sessão expirada');
      });
      await tester.pumpWidget(CorteCertoApp(
        deps: AppDependencies(
          session: session,
          authApi: MockAuthApi(),
          servicosApi: MockServicosApi(),
          agendamentoApi: MockAgendamentoApi(),
          adminAgendamentoApi: adminApi,
          clientesApi: MockClientesApi(),
        ),
        localInicial: Rotas.adminAgenda,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Agenda - Hoje'), findsNothing);
      expect(find.byKey(const Key('campo-cpf')), findsOneWidget);
    });
  });

  // ===================================================================== pendências da seção 0 (estáticas)
  group('Pendências da FASE 2 (checagens no código-fonte)', () {
    Iterable<File> dartEm(String dir) => Directory(dir)
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    test('0.1 todo ChangeNotifier de lib/ usa NotificadorSeguro', () {
      final semGuard = <String>[];
      final re = RegExp(r'class\s+(\w+)\s+extends\s+ChangeNotifier([^{]*)\{');
      for (final f in dartEm('lib')) {
        for (final m in re.allMatches(f.readAsStringSync())) {
          if (!m.group(2)!.contains('NotificadorSeguro') && m.group(1) != 'SessionController') {
            semGuard.add('${f.path}: ${m.group(1)}');
          }
        }
      }
      expect(semGuard, isEmpty);
    });

    test('0.6 fromObject não existe mais (padronizado como deErro)', () {
      final achados = [
        for (final f in [...dartEm('lib'), ...dartEm('test')])
          if (!f.path.endsWith('fase3_tester_test.dart') && f.readAsStringSync().contains('fromObject')) f.path,
      ];
      expect(achados, isEmpty);
    });

    test('0.2 Confirmado usa PopScope; 0.3 isPublica sem endsWith; 0.4 senha só [A-Za-z]; 0.5 sem "late final _hoje"', () {
      expect(File('lib/features/agendamento/presentation/agendamento_confirmado_page.dart').readAsStringSync(),
          contains('PopScope'));
      expect(File('lib/core/network/auth_interceptor.dart').readAsStringSync(), isNot(contains('endsWith')));
      expect(File('lib/core/validators/validators.dart').readAsStringSync(), isNot(contains('À-ÿ')));
      expect(File('lib/features/agendamento/presentation/agendamento_page.dart').readAsStringSync(),
          isNot(contains('late final DateTime _hoje')));
    });

    test('0.6 backend: o teste da V5 valida checksum (não só existência dos arquivos)', () {
      final f = File('../cortecerto-backend-loop/src/test/java/br/com/ninodev/cortecerto/fase2/MigrationV5SeedServicosTest.java');
      if (!f.existsSync()) {
        fail('backend não encontrado em ../cortecerto-backend-loop');
      }
      final s = f.readAsStringSync();
      expect(s, isNot(contains('migrationsAnterioresNaoForamAlteradas')));
      expect(s.toLowerCase(), contains('checksum'));
    });
  });
}
