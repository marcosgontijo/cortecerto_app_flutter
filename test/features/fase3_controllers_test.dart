// FASE 3 (developer): NotificadorSeguro, Agenda Admin, formulário do admin e Meus Agendamentos.
import 'dart:async';

import 'package:cortecerto_flutter/core/errors/api_exception.dart';
import 'package:cortecerto_flutter/core/session/session_controller.dart';
import 'package:cortecerto_flutter/features/admin/domain/agendamento_admin.dart';
import 'package:cortecerto_flutter/features/admin/presentation/agenda_admin_controller.dart';
import 'package:cortecerto_flutter/features/admin/presentation/agendamento_form_controller.dart';
import 'package:cortecerto_flutter/features/agendamento/domain/status_agendamento.dart';
import 'package:cortecerto_flutter/features/agendamento/presentation/agendamento_controller.dart';
import 'package:cortecerto_flutter/features/auth/domain/auth_models.dart';
import 'package:cortecerto_flutter/features/auth/presentation/cadastro_controller.dart';
import 'package:cortecerto_flutter/features/auth/presentation/login_controller.dart';
import 'package:cortecerto_flutter/features/meus_agendamentos/domain/meu_agendamento.dart';
import 'package:cortecerto_flutter/features/meus_agendamentos/presentation/meus_agendamentos_controller.dart';
import 'package:cortecerto_flutter/features/servicos/domain/servico.dart';
import 'package:cortecerto_flutter/features/servicos/presentation/servicos_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes.dart';

const _servico = Servico(id: 1, tipoServico: 'Corte Simples', precoServico: '35.00');

AgendamentoAdmin ag(int id, String horario, StatusAgendamento status,
        {String nome = 'Cliente', DateTime? data}) =>
    AgendamentoAdmin(
      id: id,
      data: data ?? DateTime(2030, 1, 15),
      horario: horario,
      status: status,
      servicoId: 1,
      servico: 'Corte Simples',
      clienteId: id * 10,
      nomeCliente: nome,
    );

const _conflito = ApiException(tipo: ApiErrorTipo.conflito, statusCode: 409, mensagem: 'Horário indisponível');

void main() {
  setUpAll(() {
    registerFallbackValue(_servico);
    registerFallbackValue(DateTime(2030));
    registerFallbackValue(StatusAgendamento.pendente);
    registerFallbackValue(const CadastroRequest(
        nome: 'n', telefone: 't', cpf: 'c', email: 'e', dataNascimento: 'd', senha: 's', confirmarSenha: 's'));
  });

  group('NotificadorSeguro: resposta depois do dispose não lança', () {
    test('ServicosController', () async {
      final api = MockServicosApi();
      final c = Completer<List<Servico>>();
      when(() => api.listar()).thenAnswer((_) => c.future);
      final ctrl = ServicosController(api);
      final carregando = ctrl.carregarServicos();
      ctrl.dispose();
      c.complete(const [_servico]);
      await expectLater(carregando, completes);
      expect(ctrl.descartado, isTrue);
    });

    test('AgendamentoController (horários e envio)', () async {
      final api = MockAgendamentoApi();
      final disp = Completer<List<String>>();
      when(() => api.disponibilidades(any())).thenAnswer((_) => disp.future);
      final ctrl = AgendamentoController(api);
      final f = ctrl.selecionarDia(DateTime(2030, 1, 15));
      ctrl.dispose();
      disp.complete(['09:00']);
      await expectLater(f, completes);
    });

    test('LoginController e CadastroController', () async {
      final auth = MockAuthApi();
      final c = Completer<LoginResponse>();
      when(() => auth.login(cpf: any(named: 'cpf'), senha: any(named: 'senha'))).thenAnswer((_) => c.future);
      final login = LoginController(auth, SessionController(FakeTokenStorage()));
      final f = login.entrar(cpf: '1', senha: 's');
      login.dispose();
      c.completeError(const ApiException(tipo: ApiErrorTipo.naoAutorizado, mensagem: 'x'));
      expect(await f, isFalse);

      final cad = Completer<void>();
      when(() => auth.cadastrar(any())).thenAnswer((_) => cad.future);
      final cadastro = CadastroController(auth);
      final g = cadastro.cadastrar(const CadastroRequest(
          nome: 'n', telefone: 't', cpf: 'c', email: 'e', dataNascimento: 'd', senha: 's', confirmarSenha: 's'));
      cadastro.dispose();
      cad.complete();
      expect(await g, isTrue);
    });
  });

  group('AgendaAdminController', () {
    late MockAdminAgendamentoApi api;
    late AgendaAdminController c;
    final agora = DateTime(2030, 1, 15, 10, 0);

    setUp(() {
      api = MockAdminAgendamentoApi();
      c = AgendaAdminController(api, relogio: () => agora);
    });

    test('grade tem 24 horários de 08:00 a 19:30', () {
      expect(AgendaAdminController.grade, hasLength(24));
      expect(AgendaAdminController.grade.first, '08:00');
      expect(AgendaAdminController.grade.last, '19:30');
    });

    test('slots: ativo vence cancelado no mesmo horário; só cancelado = disponível; fora da grade aparece',
        () async {
      when(() => api.listar(any())).thenAnswer((_) async => [
            ag(1, '09:00', StatusAgendamento.cancelado),
            ag(2, '09:00', StatusAgendamento.confirmado, nome: 'Ativo'),
            ag(3, '10:00', StatusAgendamento.cancelado),
            ag(4, '18:15', StatusAgendamento.pendente),
          ]);
      await c.carregar();
      final slots = {for (final s in c.slots) s.horario: s};
      expect(slots, hasLength(25));
      expect(slots['09:00']!.agendamento!.id, 2);
      expect(slots['09:00']!.cancelados.single.id, 1);
      expect(slots['10:00']!.disponivel, isTrue);
      expect(slots['10:00']!.cancelados, hasLength(1));
      expect(slots['18:15']!.agendamento!.id, 4);
      expect(c.slots.map((s) => s.horario).toList(), orderedEquals(slots.keys.toList()..sort()));
    });

    test('contadores, filtro de status e busca por nome (sem diferenciar maiúsculas)', () async {
      when(() => api.listar(any())).thenAnswer((_) async => [
            ag(1, '09:00', StatusAgendamento.pendente, nome: 'Ana Souza'),
            ag(2, '10:00', StatusAgendamento.confirmado, nome: 'Bruno'),
            ag(3, '11:00', StatusAgendamento.confirmado, nome: 'Ana Lima'),
            ag(4, '11:00', StatusAgendamento.cancelado, nome: 'Carlos'),
            ag(5, '12:00', StatusAgendamento.realizado, nome: 'Dani'),
          ]);
      await c.carregar();
      expect(c.total, 5);
      expect(c.contar(StatusAgendamento.pendente), 1);
      expect(c.contar(StatusAgendamento.confirmado), 2);
      expect(c.contar(StatusAgendamento.cancelado), 1);
      expect(c.contar(StatusAgendamento.realizado), 1);
      c.filtrarStatus(StatusAgendamento.confirmado);
      expect(c.filtrados.map((a) => a.id), [2, 3]);
      c.buscar('ANA');
      expect(c.filtrados.map((a) => a.id), [3]);
      c.filtrarStatus(null);
      expect(c.filtrados.map((a) => a.id), [1, 3]);
      expect(c.temFiltro, isTrue);
    });

    test('Hoje/Amanhã/data recarregam do servidor com o dia certo', () async {
      when(() => api.listar(any())).thenAnswer((_) async => []);
      await c.carregar();
      await c.selecionarAmanha();
      await c.selecionarData(DateTime(2030, 2, 1));
      expect(c.periodo, PeriodoAgenda.data);
      await c.selecionarData(DateTime(2030, 1, 15, 18));
      expect(c.periodo, PeriodoAgenda.hoje);
      verifyInOrder([
        () => api.listar(DateTime(2030, 1, 15)),
        () => api.listar(DateTime(2030, 1, 16)),
        () => api.listar(DateTime(2030, 2, 1)),
        () => api.listar(DateTime(2030, 1, 15)),
      ]);
    });

    test('ações chamam a API certa e recarregam; 409 vira erro de conflito', () async {
      when(() => api.listar(any())).thenAnswer((_) async => []);
      final a = ag(7, '09:00', StatusAgendamento.pendente);
      when(() => api.atualizar(7, status: any(named: 'status'))).thenAnswer((_) async => a);
      when(() => api.cancelar(7)).thenAnswer((_) async {});
      when(() => api.excluir(7)).thenAnswer((_) async {});

      expect((await c.confirmar(a)).sucesso, isTrue);
      verify(() => api.atualizar(7, status: StatusAgendamento.confirmado)).called(1);
      expect((await c.marcarRealizado(a)).sucesso, isTrue);
      verify(() => api.atualizar(7, status: StatusAgendamento.realizado)).called(1);
      expect((await c.cancelar(a)).sucesso, isTrue);
      expect((await c.excluir(a)).sucesso, isTrue);
      verify(() => api.listar(any())).called(4);

      when(() => api.atualizar(7, status: any(named: 'status'))).thenThrow(_conflito);
      final r = await c.confirmar(a);
      expect(r.sucesso, isFalse);
      expect(r.conflito, isTrue);
      expect(r.mensagem, 'Horário indisponível');
      verify(() => api.listar(any())).called(1);
    });

    test('erro ao carregar mostra mensagem', () async {
      when(() => api.listar(any())).thenThrow(
          const ApiException(tipo: ApiErrorTipo.semConexao, mensagem: ApiErrorMapper.msgSemConexao));
      await c.carregar();
      expect(c.erro, ApiErrorMapper.msgSemConexao);
    });
  });

  group('AgendamentoFormController', () {
    late MockAdminAgendamentoApi admin;
    late MockClientesApi clientes;
    late MockAgendamentoApi agenda;
    late MockServicosApi servicos;

    setUp(() {
      admin = MockAdminAgendamentoApi();
      clientes = MockClientesApi();
      agenda = MockAgendamentoApi();
      servicos = MockServicosApi();
      when(() => servicos.listar()).thenAnswer((_) async => const [_servico]);
    });

    AgendamentoFormController criar(AgendamentoFormArgs args) => AgendamentoFormController(
        adminApi: admin, clientesApi: clientes, agendamentoApi: agenda, servicosApi: servicos, args: args);

    test('criar: busca cliente, escolhe serviço/horário e envia status', () async {
      when(() => agenda.disponibilidades(any())).thenAnswer((_) async => ['09:00', '09:30']);
      when(() => clientes.buscar('ana')).thenAnswer((_) async => const [ClienteResumo(id: 5, nome: 'Ana')]);
      when(() => admin.criar(
            clienteId: any(named: 'clienteId'),
            servicoId: any(named: 'servicoId'),
            data: any(named: 'data'),
            horario: any(named: 'horario'),
            status: any(named: 'status'),
          )).thenAnswer((_) async => ag(1, '09:30', StatusAgendamento.pendente));
      final c = criar(AgendamentoFormArgs.criar(data: DateTime(2030, 1, 15), horario: '09:30'));
      await c.iniciar();
      expect(c.horario, '09:30');
      expect(c.statusDisponiveis, isNot(contains(StatusAgendamento.cancelado)));
      expect(c.podeSalvar, isFalse);
      await c.buscarClientes('ana');
      c.selecionarCliente(c.clientes.single);
      c.selecionarServico(1);
      c.selecionarStatus(StatusAgendamento.pendente);
      expect(await c.salvar(), isTrue);
      verify(() => admin.criar(
          clienteId: 5,
          servicoId: 1,
          data: DateTime(2030, 1, 15),
          horario: '09:30',
          status: StatusAgendamento.pendente)).called(1);
    });

    test('editar: oferece o próprio horário; 409 mostra a mensagem e recarrega os horários', () async {
      var chamadas = 0;
      when(() => agenda.disponibilidades(any())).thenAnswer((_) async {
        chamadas++;
        return ['10:00'];
      });
      when(() => admin.atualizar(any(),
              servicoId: any(named: 'servicoId'),
              data: any(named: 'data'),
              horario: any(named: 'horario'),
              status: any(named: 'status')))
          .thenThrow(_conflito);
      final c = criar(AgendamentoFormArgs.editar(ag(3, '09:00', StatusAgendamento.confirmado)));
      await c.iniciar();
      expect(c.horarios, ['09:00', '10:00']);
      expect(c.horario, '09:00');
      expect(c.servicoId, 1);
      expect(c.cliente!.nome, 'Cliente');
      c.selecionarHorario('10:00');
      expect(await c.salvar(), isFalse);
      expect(c.erroSalvar, 'Horário indisponível');
      expect(c.horario, isNull);
      expect(chamadas, 2);
    });
  });

  group('MeusAgendamentosController', () {
    late MockAgendamentoApi api;
    late MeusAgendamentosController c;
    final agora = DateTime(2030, 1, 15, 10, 0);

    MeuAgendamento m(int id, DateTime data, String h, StatusAgendamento s) =>
        MeuAgendamento(id: id, data: data, horario: h, status: s, servico: 'Corte');

    setUp(() {
      api = MockAgendamentoApi();
      c = MeusAgendamentosController(api, relogio: () => agora);
    });

    test('separa Próximos (futuros ativos, mais próximo primeiro) e Histórico', () async {
      when(() => api.meus()).thenAnswer((_) async => [
            m(1, DateTime(2030, 1, 20), '09:00', StatusAgendamento.confirmado),
            m(2, DateTime(2030, 1, 16), '09:00', StatusAgendamento.pendente),
            m(3, DateTime(2030, 1, 18), '09:00', StatusAgendamento.cancelado),
            m(4, DateTime(2030, 1, 15), '09:30', StatusAgendamento.confirmado), // já passou
            m(5, DateTime(2030, 1, 10), '09:00', StatusAgendamento.realizado),
          ]);
      await c.carregar();
      expect(c.proximos.map((a) => a.id), [2, 1]);
      expect(c.historico.map((a) => a.id), [3, 4, 5]);
      expect(c.podeCancelar(c.proximos.first), isTrue);
      expect(c.historico.any(c.podeCancelar), isFalse);
    });

    test('cancelar chama a API e recarrega; erro devolve a mensagem', () async {
      final a = m(2, DateTime(2030, 1, 16), '09:00', StatusAgendamento.pendente);
      when(() => api.meus()).thenAnswer((_) async => [a]);
      when(() => api.cancelar(2)).thenAnswer((_) async {});
      await c.carregar();
      expect(await c.cancelar(a), isNull);
      verify(() => api.meus()).called(2);
      when(() => api.cancelar(2)).thenThrow(
          const ApiException(tipo: ApiErrorTipo.dadosInvalidos, mensagem: 'Não é possível cancelar'));
      expect(await c.cancelar(a), 'Não é possível cancelar');
    });
  });
}
