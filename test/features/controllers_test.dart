import 'package:cortecerto_flutter/core/errors/api_exception.dart';
import 'package:cortecerto_flutter/core/session/session_controller.dart';
import 'package:cortecerto_flutter/core/session/usuario.dart';
import 'package:cortecerto_flutter/features/agendamento/presentation/agendamento_controller.dart';
import 'package:cortecerto_flutter/features/auth/domain/auth_models.dart';
import 'package:cortecerto_flutter/features/auth/presentation/cadastro_controller.dart';
import 'package:cortecerto_flutter/features/auth/presentation/login_controller.dart';
import 'package:cortecerto_flutter/features/produtos/presentation/produtos_controller.dart';
import 'package:cortecerto_flutter/features/servicos/domain/servico.dart';
import 'package:cortecerto_flutter/features/servicos/presentation/servicos_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes.dart';

const _req = CadastroRequest(
  nome: 'Maria',
  telefone: '11987654321',
  cpf: '52998224725',
  email: 'maria@mail.com',
  dataNascimento: '1990-03-15',
  senha: 'abc12345',
  confirmarSenha: 'abc12345',
);

const _servico = Servico(id: 1, tipoServico: 'Corte Simples', descricao: 'd', precoServico: '35.00');

ApiException _erro(ApiErrorTipo tipo, [String msg = 'msg', Map<String, String> campos = const {}]) =>
    ApiException(tipo: tipo, mensagem: msg, errosPorCampo: campos);

void main() {
  setUpAll(() {
    registerFallbackValue(_req);
    registerFallbackValue(_servico);
    registerFallbackValue(DateTime(2030));
  });

  group('LoginController', () {
    late MockAuthApi api;
    late FakeTokenStorage storage;
    late SessionController session;

    setUp(() {
      api = MockAuthApi();
      storage = FakeTokenStorage();
      session = SessionController(storage);
    });

    test('sucesso inicia a sessão', () async {
      when(() => api.login(cpf: '52998224725', senha: 'abc12345')).thenAnswer((_) async =>
          const LoginResponse(token: 'tok', usuario: Usuario(id: 1, nome: 'Maria', role: 'CLIENTE')));
      final c = LoginController(api, session);
      final estados = <bool>[];
      c.addListener(() => estados.add(c.isLoading));
      expect(await c.entrar(cpf: '52998224725', senha: 'abc12345'), isTrue);
      expect(estados.first, isTrue);
      expect(c.isLoading, isFalse);
      expect(storage.token, 'tok');
      expect(session.usuario!.nome, 'Maria');
    });

    test('401 → CPF ou senha inválidos; 423 e 429 com mensagem própria', () async {
      final c = LoginController(api, session);
      when(() => api.login(cpf: any(named: 'cpf'), senha: any(named: 'senha')))
          .thenThrow(_erro(ApiErrorTipo.naoAutorizado));
      expect(await c.entrar(cpf: '1', senha: 's'), isFalse);
      expect(c.erro, 'CPF ou senha inválidos');
      expect(session.isAutenticado, isFalse);

      when(() => api.login(cpf: any(named: 'cpf'), senha: any(named: 'senha')))
          .thenThrow(_erro(ApiErrorTipo.bloqueado, ApiErrorMapper.msgBloqueado));
      await c.entrar(cpf: '1', senha: 's');
      expect(c.erro, ApiErrorMapper.msgBloqueado);

      when(() => api.login(cpf: any(named: 'cpf'), senha: any(named: 'senha')))
          .thenThrow(_erro(ApiErrorTipo.muitasTentativas, ApiErrorMapper.msgMuitasTentativas));
      await c.entrar(cpf: '1', senha: 's');
      expect(c.erro, ApiErrorMapper.msgMuitasTentativas);
    });
  });

  group('CadastroController', () {
    test('sucesso', () async {
      final api = MockAuthApi();
      when(() => api.cadastrar(any())).thenAnswer((_) async {});
      final c = CadastroController(api);
      expect(await c.cadastrar(_req), isTrue);
      expect(c.erro, isNull);
    });

    test('400 com erros por campo e 409', () async {
      final api = MockAuthApi();
      final c = CadastroController(api);
      when(() => api.cadastrar(any())).thenThrow(
          _erro(ApiErrorTipo.dadosInvalidos, 'Dados inválidos', {'cpf': 'CPF inválido'}));
      expect(await c.cadastrar(_req), isFalse);
      expect(c.erroDoCampo('cpf'), 'CPF inválido');
      c.limparErroDoCampo('cpf');
      expect(c.erroDoCampo('cpf'), isNull);

      when(() => api.cadastrar(any())).thenThrow(_erro(ApiErrorTipo.conflito));
      await c.cadastrar(_req);
      expect(c.erro, 'CPF ou e-mail já cadastrado');
    });
  });

  group('ServicosController', () {
    test('carrega, vazio e erro', () async {
      final api = MockServicosApi();
      final c = ServicosController(api);
      when(() => api.listar()).thenAnswer((_) async => [_servico]);
      final f = c.carregarServicos();
      expect(c.isLoading, isTrue);
      await f;
      expect(c.servicos, [_servico]);
      expect(c.isVazio, isFalse);

      when(() => api.listar()).thenAnswer((_) async => []);
      await c.carregarServicos();
      expect(c.isVazio, isTrue);

      when(() => api.listar()).thenThrow(_erro(ApiErrorTipo.semConexao, 'sem rede'));
      await c.carregarServicos();
      expect(c.erro, 'sem rede');
      expect(c.isVazio, isFalse);
    });
  });

  group('AgendamentoController', () {
    late MockAgendamentoApi api;
    final dia = DateTime(2030, 1, 15);

    setUp(() => api = MockAgendamentoApi());

    test('carrega horários do dia e confirma', () async {
      when(() => api.disponibilidades(dia)).thenAnswer((_) async => ['08:00', '08:30']);
      when(() => api.agendar(data: dia, horario: '08:30', servico: _servico))
          .thenAnswer((_) async {});
      final c = AgendamentoController(api);
      expect(c.podeConfirmar, isFalse);
      await c.selecionarDia(dia);
      expect(c.horarios, ['08:00', '08:30']);
      c.selecionarHorario('08:30');
      final r = await c.confirmar(_servico);
      expect(r!.horario, '08:30');
      expect(r.servico, 'Corte Simples');
      expect(r.data, dia);
    });

    test('409 avisa e recarrega horários', () async {
      var chamadas = 0;
      when(() => api.disponibilidades(dia)).thenAnswer((_) async {
        chamadas++;
        return chamadas == 1 ? ['08:00', '08:30'] : ['08:00'];
      });
      when(() => api.agendar(
              data: any(named: 'data'),
              horario: any(named: 'horario'),
              servico: any(named: 'servico')))
          .thenThrow(_erro(ApiErrorTipo.conflito, 'Horário indisponível'));
      final c = AgendamentoController(api);
      await c.selecionarDia(dia);
      c.selecionarHorario('08:30');
      expect(await c.confirmar(_servico), isNull);
      expect(c.aviso, AgendamentoController.msgHorarioReservado);
      expect(c.horarios, ['08:00']);
      expect(c.horarioSelecionado, isNull);
      expect(chamadas, 2);
    });

    test('400 mostra a mensagem do backend', () async {
      when(() => api.disponibilidades(dia)).thenAnswer((_) async => ['08:00']);
      when(() => api.agendar(
              data: any(named: 'data'),
              horario: any(named: 'horario'),
              servico: any(named: 'servico')))
          .thenThrow(_erro(ApiErrorTipo.dadosInvalidos, 'Serviço não encontrado'));
      final c = AgendamentoController(api);
      await c.selecionarDia(dia);
      c.selecionarHorario('08:00');
      expect(await c.confirmar(_servico), isNull);
      expect(c.erroEnvio, 'Serviço não encontrado');
    });
  });

  test('ProdutosController: seleção múltipla e total', () {
    final c = ProdutosController();
    expect(c.produtos.map((p) => p.nome), ['Pomada', 'Shampoo', 'Pente']);
    expect(c.total, 0);
    c.alternar(c.produtos[0]);
    c.alternar(c.produtos[2]);
    expect(c.total, 35.0);
    c.alternar(c.produtos[0]);
    expect(c.total, 10.0);
    expect(c.selecionados.single.nome, 'Pente');
  });
}
