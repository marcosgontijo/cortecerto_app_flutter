// FASE 4 (tester): monta cada uma das 10 telas com APIs fake e tema real, no estado
// principal (dados carregados) ou em estados extras (erro, vazio, sheet aberto...).
import 'package:cortecerto_flutter/core/errors/api_exception.dart';
import 'package:cortecerto_flutter/core/router/rotas.dart';
import 'package:cortecerto_flutter/core/session/session_controller.dart';
import 'package:cortecerto_flutter/core/session/usuario.dart';
import 'package:cortecerto_flutter/core/theme/app_theme.dart';
import 'package:cortecerto_flutter/core/widgets/estados.dart';
import 'package:cortecerto_flutter/features/admin/data/admin_agendamento_api.dart';
import 'package:cortecerto_flutter/features/admin/data/clientes_api.dart';
import 'package:cortecerto_flutter/features/admin/domain/agendamento_admin.dart';
import 'package:cortecerto_flutter/features/admin/presentation/admin_page.dart';
import 'package:cortecerto_flutter/features/admin/presentation/agenda_admin_controller.dart';
import 'package:cortecerto_flutter/features/admin/presentation/agenda_admin_page.dart';
import 'package:cortecerto_flutter/features/admin/presentation/agendamento_form_controller.dart';
import 'package:cortecerto_flutter/features/admin/presentation/agendamento_form_page.dart';
import 'package:cortecerto_flutter/features/admin/domain/faturamento.dart';
import 'package:cortecerto_flutter/features/admin/presentation/faturamento_controller.dart';
import 'package:cortecerto_flutter/features/admin/presentation/faturamento_page.dart';
import 'package:cortecerto_flutter/features/agendamento/data/agendamento_api.dart';
import 'package:cortecerto_flutter/features/agendamento/domain/agendamento_confirmado.dart';
import 'package:cortecerto_flutter/features/agendamento/domain/status_agendamento.dart';
import 'package:cortecerto_flutter/features/agendamento/presentation/agendamento_confirmado_page.dart';
import 'package:cortecerto_flutter/features/agendamento/presentation/agendamento_controller.dart';
import 'package:cortecerto_flutter/features/agendamento/presentation/agendamento_page.dart';
import 'package:cortecerto_flutter/features/auth/data/auth_api.dart';
import 'package:cortecerto_flutter/features/auth/presentation/cadastro_controller.dart';
import 'package:cortecerto_flutter/features/auth/presentation/cadastro_page.dart';
import 'package:cortecerto_flutter/features/auth/presentation/login_controller.dart';
import 'package:cortecerto_flutter/features/auth/presentation/login_page.dart';
import 'package:cortecerto_flutter/features/meus_agendamentos/domain/meu_agendamento.dart';
import 'package:cortecerto_flutter/features/meus_agendamentos/presentation/meus_agendamentos_controller.dart';
import 'package:cortecerto_flutter/features/meus_agendamentos/presentation/meus_agendamentos_page.dart';
import 'package:cortecerto_flutter/features/produtos/presentation/produtos_controller.dart';
import 'package:cortecerto_flutter/features/produtos/presentation/produtos_page.dart';
import 'package:cortecerto_flutter/features/servicos/data/servicos_api.dart';
import 'package:cortecerto_flutter/features/servicos/domain/servico.dart';
import 'package:cortecerto_flutter/features/servicos/presentation/servicos_controller.dart';
import 'package:cortecerto_flutter/features/servicos/presentation/servicos_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../helpers/fakes.dart';
import '../helpers/widget_helpers.dart';

const servicoTeste =
    Servico(id: 1, tipoServico: 'Corte Simples', descricao: 'Corte básico', precoServico: '35.00');
const barbaTeste = Servico(id: 2, tipoServico: 'Barba', descricao: 'Barba feita', precoServico: '25.00');
final diaTeste = DateTime(2030, 1, 15);
const semConexao = ApiException(tipo: ApiErrorTipo.semConexao, mensagem: ApiErrorMapper.msgSemConexao);

AgendamentoAdmin agAdmin(int id, String horario, StatusAgendamento status, String nome) => AgendamentoAdmin(
      id: id,
      data: diaTeste,
      horario: horario,
      status: status,
      servicoId: 1,
      servico: 'Corte Simples',
      clienteId: 50 + id,
      nomeCliente: nome,
      telefoneCliente: '11999990000',
    );

/// As 10 telas da TAREFA (seção 3) + Faturamento (FASE 5).
enum TelaF4 {
  login,
  cadastro,
  servicos,
  produtos,
  agendamento,
  confirmado,
  meus,
  painelAdmin,
  agendaAdmin,
  formAdmin,
  // FASE 5 (developer): entra sozinha nos grupos que percorrem TelaF4.values
  faturamento,
}

/// Estados extras testados nos guidelines.
/// `inicial` (só Agendamento): tela recém-aberta, sem dia escolhido.
/// `vazio` no Agendamento: dia escolhido e a API de disponibilidade devolve `[]`.
/// Volta 4 (só formAdmin): `erroServicos` (servicosApi.listar falha), `vazioServicos` (lista vazia),
/// `vazioHorarios` (disponibilidades devolve []).
/// Volta 5 (só formAdmin): `erroClientes` (clientesApi.buscar falha depois de buscar 'mar').
/// FASE 5 (só faturamento): `semana` e `mes` trocam o período depois de abrir (lista por dia com barras).
enum EstadoF4 {
  principal,
  inicial,
  erro,
  vazio,
  detalhes,
  erroServicos,
  vazioServicos,
  vazioHorarios,
  erroClientes,
  semana,
  mes,
}

/// Faturamento fake (FASE 5) para o período pedido: um dia com recebido, os outros zerados.
Faturamento faturamentoFake(DateTime inicio, DateTime fim, {bool vazio = false}) {
  final dias = <FaturamentoDia>[];
  for (var d = inicio; !d.isAfter(fim); d = DateTime(d.year, d.month, d.day + 1)) {
    final i = dias.length;
    dias.add(FaturamentoDia(
      data: d,
      recebidoCentavos: vazio ? 0 : (i == 0 ? 123450 : (i == 1 ? 3500 : 0)),
      previstoCentavos: i == 0 ? 5500 : 0,
    ));
  }
  return Faturamento(
    inicio: inicio,
    fim: fim,
    recebidoCentavos: vazio ? 0 : dias.fold(0, (s, d) => s + d.recebidoCentavos),
    previstoCentavos: 5500,
    quantidadeRealizados: vazio ? 0 : (dias.length > 1 ? 31 : 30),
    quantidadePrevistos: 1,
    porDia: dias,
    porServico: vazio
        ? const []
        : const [
            FaturamentoServico(servico: 'Corte + Barba', quantidade: 20, recebidoCentavos: 110000),
            FaturamentoServico(servico: 'Corte Simples', quantidade: 11, recebidoCentavos: 16950),
          ],
  );
}

void registrarFallbacks() {
  registerFallbackValue(servicoTeste);
  registerFallbackValue(DateTime(2030));
  registerFallbackValue(StatusAgendamento.pendente);
}

Future<void> tocarVisivel(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    // listas preguiçosas: rola o primeiro Scrollable vertical até construir o item
    final rolavel = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
    await tester.scrollUntilVisible(f, 200, scrollable: rolavel.first);
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Monta [tela] no [estado] pedido e deixa a tela estável (`pumpAndSettle`).
/// Devolve o tipo da página, para os testes acharem o contexto dela.
Future<Type> abrirTela(WidgetTester tester, TelaF4 tela,
    {EstadoF4 estado = EstadoF4.principal,
    Future<List<ClienteResumo>> Function(String)? buscaClientes,
    Future<List<String>> Function(DateTime)? horariosForm,
    Future<List<Servico>> Function()? servicosForm,
    bool assentar = true}) async {
  final cliente = SessionController(FakeTokenStorage());
  await cliente.iniciar('t', const Usuario(id: 3, nome: 'Maria', role: 'CLIENTE'));
  final admin = SessionController(FakeTokenStorage());
  await admin.iniciar('t', const Usuario(id: 9, nome: 'Chefe', role: 'ADMIN'));

  switch (tela) {
    case TelaF4.login:
      final api = MockAuthApi();
      final s = SessionController(FakeTokenStorage());
      when(() => api.login(cpf: any(named: 'cpf'), senha: any(named: 'senha'))).thenThrow(semConexao);
      await tester.pumpWidget(comRouter(const LoginPage(), providers: [
        ChangeNotifierProvider<SessionController>.value(value: s),
        Provider<AuthApi>.value(value: api),
        ChangeNotifierProvider(create: (_) => LoginController(api, s)),
      ]));
      await tester.pumpAndSettle();
      if (estado == EstadoF4.erro) {
        await tester.enterText(find.byKey(const Key('campo-cpf')), '52998224725');
        await tester.enterText(find.byKey(const Key('campo-senha')), 'abc12345');
        await tocarVisivel(tester, find.byKey(const Key('botao-entrar')));
        expect(find.byKey(const Key('erro-login')), findsOneWidget);
      }
      return LoginPage;

    case TelaF4.cadastro:
      final api = MockAuthApi();
      final s = SessionController(FakeTokenStorage());
      await tester.pumpWidget(comRouter(const CadastroPage(), providers: [
        ChangeNotifierProvider<SessionController>.value(value: s),
        ChangeNotifierProvider(create: (_) => CadastroController(api)),
      ]));
      await tester.pumpAndSettle();
      if (estado == EstadoF4.erro) {
        // validação local: erros embaixo dos campos
        await tocarVisivel(tester, find.byKey(const Key('botao-cadastrar')));
      }
      return CadastroPage;

    case TelaF4.servicos:
      final api = MockServicosApi();
      if (estado == EstadoF4.erro) {
        when(() => api.listar()).thenThrow(semConexao);
      } else if (estado == EstadoF4.vazio) {
        when(() => api.listar()).thenAnswer((_) async => const []);
      } else {
        when(() => api.listar()).thenAnswer((_) async => const [servicoTeste, barbaTeste]);
      }
      await tester.pumpWidget(comRouter(const ServicosPage(), providers: [
        ChangeNotifierProvider<SessionController>.value(value: cliente),
        ChangeNotifierProvider(create: (_) => ServicosController(api)),
      ]));
      await tester.pumpAndSettle();
      return ServicosPage;

    case TelaF4.produtos:
      await tester.pumpWidget(comRouter(const ProdutosPage(), providers: [
        ChangeNotifierProvider<SessionController>.value(value: cliente),
        ChangeNotifierProvider(create: (_) => ProdutosController()),
      ]));
      await tester.pumpAndSettle();
      // um produto selecionado (barra com total)
      await tocarVisivel(tester, find.byKey(const Key('produto-1')));
      return ProdutosPage;

    case TelaF4.agendamento:
      final api = MockAgendamentoApi();
      if (estado == EstadoF4.vazio) {
        when(() => api.disponibilidades(any())).thenAnswer((_) async => const <String>[]);
      } else {
        when(() => api.disponibilidades(any())).thenAnswer((_) async => ['08:00', '08:30', '10:00']);
      }
      await tester.pumpWidget(comRouter(AgendamentoPage(servico: servicoTeste, hoje: DateTime(2030, 1, 10)),
          providers: [
            ChangeNotifierProvider<SessionController>.value(value: cliente),
            ChangeNotifierProvider(create: (_) => AgendamentoController(api)),
          ]));
      await tester.pumpAndSettle();
      if (estado == EstadoF4.vazio) {
        await tocarVisivel(tester, find.text('15'));
        verify(() => api.disponibilidades(DateTime(2030, 1, 15))).called(1);
        expect(find.byKey(const Key('horarios-vazio')), findsOneWidget);
        expect(find.byWidgetPredicate((w) => w is ChoiceChip), findsNothing);
      } else if (estado != EstadoF4.inicial) {
        await tocarVisivel(tester, find.text('15'));
        await tocarVisivel(tester, find.byKey(const Key('horario-08:30')));
        expect(find.byKey(const Key('agendamento-resumo')), findsOneWidget);
      }
      return AgendamentoPage;

    case TelaF4.confirmado:
      await tester.pumpWidget(comRouter(
        AgendamentoConfirmadoPage(
          resumo: AgendamentoConfirmado(servico: 'Corte Simples', data: DateTime(2030, 1, 15), horario: '09:00'),
        ),
        providers: [ChangeNotifierProvider<SessionController>.value(value: cliente)],
      ));
      await tester.pumpAndSettle();
      return AgendamentoConfirmadoPage;

    case TelaF4.meus:
      final api = MockAgendamentoApi();
      MeuAgendamento m(int id, DateTime d, String h, StatusAgendamento s, String sv) =>
          MeuAgendamento(id: id, data: d, horario: h, status: s, servico: sv);
      if (estado == EstadoF4.vazio) {
        when(() => api.meus()).thenAnswer((_) async => []);
      } else if (estado == EstadoF4.erro) {
        when(() => api.meus()).thenThrow(semConexao);
      } else {
        when(() => api.meus()).thenAnswer((_) async => [
              m(1, DateTime(2030, 1, 20), '09:00', StatusAgendamento.confirmado, 'Barba'),
              m(4, DateTime(2030, 1, 21), '10:00', StatusAgendamento.pendente, 'Corte Simples'),
              m(2, DateTime(2030, 1, 10), '09:00', StatusAgendamento.realizado, 'Sobrancelha'),
            ]);
      }
      await tester.pumpWidget(comRouter(const MeusAgendamentosPage(), providers: [
        ChangeNotifierProvider<SessionController>.value(value: cliente),
        ChangeNotifierProvider(
            create: (_) => MeusAgendamentosController(api, relogio: () => DateTime(2030, 1, 15, 10))),
      ]));
      await tester.pumpAndSettle();
      return MeusAgendamentosPage;

    case TelaF4.painelAdmin:
      await tester.pumpWidget(comRouter(const AdminPage(), providers: [
        ChangeNotifierProvider<SessionController>.value(value: admin),
      ]));
      await tester.pumpAndSettle();
      return AdminPage;

    case TelaF4.faturamento:
      final api = MockAdminAgendamentoApi();
      if (estado == EstadoF4.erro) {
        when(() => api.faturamento(any(), any())).thenThrow(semConexao);
      } else {
        when(() => api.faturamento(any(), any())).thenAnswer((i) async => faturamentoFake(
            i.positionalArguments[0] as DateTime, i.positionalArguments[1] as DateTime,
            vazio: estado == EstadoF4.vazio));
      }
      await tester.pumpWidget(comRouter(const FaturamentoPage(), providers: [
        ChangeNotifierProvider<SessionController>.value(value: admin),
        ChangeNotifierProvider(create: (_) => FaturamentoController(api, relogio: () => diaTeste)),
      ]));
      await tester.pumpAndSettle();
      // confere que o estado pedido está MESMO na tela e o traz para dentro dela
      // (a ListView é preguiçosa e os guidelines só avaliam o que está na tela)
      Future<void> trazerParaATela(Finder f) async {
        if (f.evaluate().isEmpty) {
          final rolavel = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
          await tester.scrollUntilVisible(f, 200, scrollable: rolavel.first);
        }
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        expect(f, findsOneWidget);
      }

      if (estado == EstadoF4.semana || estado == EstadoF4.mes) {
        await tocarVisivel(tester, find.byKey(Key('faturamento-tipo-${estado == EstadoF4.semana ? 'semana' : 'mes'}')));
        await trazerParaATela(find.byKey(const Key('faturamento-por-dia')));
      } else {
        await trazerParaATela(find.byKey(Key(switch (estado) {
          EstadoF4.erro => 'faturamento-erro',
          EstadoF4.vazio => 'faturamento-vazio',
          _ => 'faturamento-recebido',
        })));
      }
      return FaturamentoPage;

    case TelaF4.agendaAdmin:
    case TelaF4.formAdmin:
      final api = MockAdminAgendamentoApi();
      final clientesApi = MockClientesApi();
      final agApi = MockAgendamentoApi();
      final servApi = MockServicosApi();
      if (estado == EstadoF4.erro && tela == TelaF4.agendaAdmin) {
        when(() => api.listar(any())).thenThrow(semConexao);
      } else if (estado == EstadoF4.vazio && tela == TelaF4.agendaAdmin) {
        when(() => api.listar(any())).thenAnswer((_) async => []);
      } else {
        when(() => api.listar(any())).thenAnswer((_) async => [
              agAdmin(1, '09:00', StatusAgendamento.pendente, 'Ana Souza'),
              agAdmin(2, '10:00', StatusAgendamento.confirmado, 'Bruno Lima'),
              agAdmin(3, '10:30', StatusAgendamento.cancelado, 'Carlos Dias'),
              agAdmin(4, '11:00', StatusAgendamento.realizado, 'Dani Rocha'),
            ]);
      }
      if (servicosForm != null) {
        when(() => servApi.listar()).thenAnswer((_) => servicosForm());
      } else if (estado == EstadoF4.erroServicos && tela == TelaF4.formAdmin) {
        when(() => servApi.listar()).thenThrow(semConexao);
      } else if (estado == EstadoF4.vazioServicos && tela == TelaF4.formAdmin) {
        when(() => servApi.listar()).thenAnswer((_) async => const <Servico>[]);
      } else {
        when(() => servApi.listar()).thenAnswer((_) async => const [servicoTeste, barbaTeste]);
      }
      if (horariosForm != null) {
        when(() => agApi.disponibilidades(any()))
            .thenAnswer((i) => horariosForm(i.positionalArguments.first as DateTime));
      } else {
        if (estado == EstadoF4.vazioHorarios && tela == TelaF4.formAdmin) {
          when(() => agApi.disponibilidades(any())).thenAnswer((_) async => const <String>[]);
        } else {
          when(() => agApi.disponibilidades(any())).thenAnswer((_) async => ['12:00', '12:30']);
        }
      }
      if (buscaClientes != null) {
        when(() => clientesApi.buscar(any())).thenAnswer((i) => buscaClientes(i.positionalArguments.first as String));
      } else if (estado == EstadoF4.erroClientes) {
        when(() => clientesApi.buscar(any())).thenThrow(semConexao);
      } else if (estado == EstadoF4.vazio) {
        when(() => clientesApi.buscar(any())).thenAnswer((_) async => const []);
      } else {
        when(() => clientesApi.buscar(any())).thenAnswer((_) async =>
            const [ClienteResumo(id: 77, nome: 'Marcos', cpf: '***.***.***-25', telefone: '11988887777')]);
      }
      final Widget raiz = tela == TelaF4.agendaAdmin
          ? ChangeNotifierProvider(
              create: (_) => AgendaAdminController(api, relogio: () => DateTime(2030, 1, 15, 8)),
              child: const AgendaAdminPage(),
            )
          : ChangeNotifierProvider(
              create: (_) => AgendamentoFormController(
                adminApi: api,
                clientesApi: clientesApi,
                agendamentoApi: agApi,
                servicosApi: servApi,
                args: AgendamentoFormArgs.criar(data: diaTeste, horario: '12:00'),
                relogio: () => DateTime(2030, 1, 15, 8),
              ),
              child: const AgendamentoFormPage(),
            );
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, _) => raiz),
        GoRoute(
          path: Rotas.adminAgendamentoForm,
          name: Rotas.nomeAdminAgendamentoForm,
          builder: (_, _) => const Scaffold(body: Text('TELA form')),
        ),
        GoRoute(path: Rotas.admin, name: Rotas.nomeAdmin, builder: (_, _) => const Text('TELA admin')),
        GoRoute(path: Rotas.login, name: Rotas.nomeLogin, builder: (_, _) => const Text('TELA login')),
      ]);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: admin),
          Provider<AdminAgendamentoApi>.value(value: api),
          Provider<ClientesApi>.value(value: clientesApi),
          Provider<AgendamentoApi>.value(value: agApi),
          Provider<ServicosApi>.value(value: servApi),
        ],
        child: MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
      ));
      if (!assentar) {
        // carregando: o indicador gira para sempre, pumpAndSettle não termina
        await tester.pump();
        return tela == TelaF4.agendaAdmin ? AgendaAdminPage : AgendamentoFormPage;
      }
      await tester.pumpAndSettle();
      if (tela == TelaF4.agendaAdmin) {
        if (estado == EstadoF4.detalhes) {
          await tocarVisivel(tester, find.byKey(const Key('agenda-horario-09:00')));
          expect(find.byKey(const Key('detalhes-agendamento')), findsOneWidget);
        }
        return AgendaAdminPage;
      }
      if (estado == EstadoF4.principal || estado == EstadoF4.vazio || estado == EstadoF4.erroClientes) {
        await tester.enterText(find.byKey(const Key('campo-busca-cliente')), 'mar');
        await tocarVisivel(tester, find.byKey(const Key('botao-buscar-cliente')));
        if (estado == EstadoF4.erroClientes) {
          verify(() => clientesApi.buscar('mar')).called(1);
        } else if (estado == EstadoF4.principal) {
          await tocarVisivel(tester, find.byKey(const Key('form-cliente-77')));
          await tocarVisivel(tester, find.byKey(const Key('form-servico-1')));
        } else {
          expect(find.byKey(const Key('form-clientes-vazio')), findsOneWidget);
        }
      }
      // estados novos da volta 4: confere que o estado pedido está MESMO na tela
      // (senão os guidelines rodariam sobre o estado principal e passariam por acaso)
      // e o traz para dentro da tela (os guidelines só avaliam o que está na tela)
      final chave = switch (estado) {
        EstadoF4.erroServicos => 'form-erro-servicos',
        EstadoF4.vazioServicos => 'form-servicos-vazio',
        EstadoF4.vazioHorarios => 'form-horarios-vazio',
        EstadoF4.erroClientes => 'form-erro-clientes',
        _ => null,
      };
      if (chave != null) {
        final f = find.byKey(Key(chave));
        if (f.evaluate().isEmpty) {
          await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
        }
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        expect(f, findsOneWidget);
        // o componente padrão do estado (critério 2.1), não um texto/bloco solto com a mesma Key
        expect(tester.widget(f),
            estado == EstadoF4.erroServicos || estado == EstadoF4.erroClientes ? isA<EstadoErro>() : isA<EstadoVazio>());
        if (estado == EstadoF4.erroClientes) {
          // a mensagem e o botão do EstadoErro estão dentro do bloco com a Key
          expect(find.descendant(of: f, matching: find.text('Tentar novamente')), findsOneWidget);
        }
        final telaRect = Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
        expect(telaRect.overlaps(tester.getRect(f)), isTrue, reason: '$chave fora da tela');
      }
      return AgendamentoFormPage;
  }
}
