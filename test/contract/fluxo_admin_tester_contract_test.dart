// Contrato da FASE 3 (tester) contra o backend real, com o admin de teste do gate.
// Rodar: API_BASE_URL=http://localhost:8080/api ADMIN_CPF=... ADMIN_SENHA=... flutter test --tags contract
// Também aceita --dart-define=API_BASE_URL=... --dart-define=ADMIN_CPF=... --dart-define=ADMIN_SENHA=...
// Sem API_BASE_URL é pulado; COM API_BASE_URL e sem ADMIN_* FALHA (nunca pula quando o gate roda).
@Tags(['contract'])
library;

import 'dart:io';
import 'dart:math';

import 'package:cortecerto_flutter/core/errors/api_exception.dart';
import 'package:cortecerto_flutter/core/network/api_client.dart';
import 'package:cortecerto_flutter/features/admin/data/admin_agendamento_api.dart';
import 'package:cortecerto_flutter/features/admin/data/clientes_api.dart';
import 'package:cortecerto_flutter/features/agendamento/data/agendamento_api.dart';
import 'package:cortecerto_flutter/features/agendamento/domain/status_agendamento.dart';
import 'package:cortecerto_flutter/features/auth/data/auth_api.dart';
import 'package:cortecerto_flutter/features/auth/domain/auth_models.dart';
import 'package:cortecerto_flutter/features/meus_agendamentos/domain/meu_agendamento.dart';
import 'package:cortecerto_flutter/features/servicos/data/servicos_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';
import 'fluxo_cliente_contract_test.dart' show cpfAleatorio;

String? _config(String nome, String definido) {
  if (definido.isNotEmpty) return definido;
  final v = Platform.environment[nome];
  return (v == null || v.isEmpty) ? null : v;
}

final String? _baseUrl = _config('API_BASE_URL', const String.fromEnvironment('API_BASE_URL'));
final String? _adminCpf = _config('ADMIN_CPF', const String.fromEnvironment('ADMIN_CPF'));
final String? _adminSenha = _config('ADMIN_SENHA', const String.fromEnvironment('ADMIN_SENHA'));

Matcher _status(int s) => throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', s));

void main() {
  test(
    'tester: admin cria → cliente vê em /meus → admin edita horário e status → cliente vê novo → '
    'admin cancela → cliente vê CANCELADO → admin exclui → some de /meus; CLIENTE em rota admin → 403',
    () async {
      expect(_adminCpf, isNotNull, reason: 'ADMIN_CPF precisa chegar ao teste de contrato (gate)');
      expect(_adminSenha, isNotNull, reason: 'ADMIN_SENHA precisa chegar ao teste de contrato (gate)');
      final r = Random();
      ApiClient cliente(FakeTokenStorage s) =>
          ApiClient(tokenStorage: s, baseUrl: _baseUrl!, onUnauthorized: () async {});
      final stAdmin = FakeTokenStorage();
      final stCli = FakeTokenStorage();
      final stOutro = FakeTokenStorage();
      final cAdmin = cliente(stAdmin);
      final cCli = cliente(stCli);
      final cOutro = cliente(stOutro);
      final auth = AuthApi(cCli);

      Future<String> novoCliente(String nome, FakeTokenStorage st) async {
        final cpf = cpfAleatorio(r);
        await auth.cadastrar(CadastroRequest(
          nome: nome,
          telefone: '11912345678',
          cpf: cpf,
          email: 't3.$cpf@teste.local',
          dataNascimento: '1991-05-20',
          senha: 'Tester1234',
          confirmarSenha: 'Tester1234',
        ));
        final login = await auth.login(cpf: cpf, senha: 'Tester1234');
        expect(login.usuario.role, 'CLIENTE');
        await st.saveToken(login.token);
        return cpf;
      }

      final sufixo = r.nextInt(1 << 30).toRadixString(36);
      final nome = 'Tester Contrato $sufixo';
      final cpf = await novoCliente(nome, stCli);
      await novoCliente('Tester Outro $sufixo', stOutro);

      final loginAdmin = await auth.login(cpf: _adminCpf!, senha: _adminSenha!);
      expect(loginAdmin.usuario.role, 'ADMIN');
      await stAdmin.saveToken(loginAdmin.token);

      final admin = AdminAgendamentoApi(cAdmin);
      final busca = ClientesApi(cAdmin);
      final agendaCli = AgendamentoApi(cCli);
      final agendaAdmin = AgendamentoApi(cAdmin);

      // busca de clientes: nome parcial (sem diferenciar maiúsculas) e CPF; CPF mascarado; máx. 20
      final porNome = await busca.buscar(nome.toUpperCase());
      final achado = porNome.singleWhere((c) => c.nome == nome);
      expect(achado.cpf, '***.***.***-${cpf.substring(9)}');
      expect(achado.telefone, '11912345678');
      expect((await busca.buscar(cpf)).map((c) => c.id), contains(achado.id));
      expect((await busca.buscar('')).length, lessThanOrEqualTo(20));
      expect((await busca.buscar(_adminCpf!)), isEmpty, reason: 'a busca só traz CLIENTE');

      final servicos = await ServicosApi(cAdmin).listar();
      expect(servicos.length, greaterThanOrEqualTo(2));
      final s1 = servicos.first;
      final s2 = servicos[1];

      final hoje = DateTime.now();
      final dia = DateTime(hoje.year, hoje.month, hoje.day).add(Duration(days: 15 + r.nextInt(280)));
      final livres = await agendaAdmin.disponibilidades(dia);
      expect(livres.length, greaterThanOrEqualTo(3));
      final h1 = livres.first;
      final h2 = livres[1];
      final h3 = livres[2];

      // 1) admin cria para o cliente (status padrão CONFIRMADO); ocupa o horário
      final criado = await admin.criar(clienteId: achado.id, servicoId: s1.id, data: dia, horario: h1);
      expect(criado.status, StatusAgendamento.confirmado);
      expect(criado.horario, h1);
      expect(criado.nomeCliente, nome);
      expect(criado.telefoneCliente, '11912345678');
      expect(await agendaCli.disponibilidades(dia), isNot(contains(h1)));
      await expectLater(admin.criar(clienteId: achado.id, servicoId: s1.id, data: dia, horario: h1), _status(409));

      final listado = (await admin.listar(dia)).singleWhere((a) => a.id == criado.id);
      expect(listado.servicoId, s1.id);
      expect(listado.clienteId, achado.id);

      // 2) cliente vê em /meus
      List<MeuAgendamento> meus = await agendaCli.meus();
      expect(meus.map((m) => m.id), [criado.id]);
      expect(meus.single.horario, h1);
      expect(meus.single.status, StatusAgendamento.confirmado);
      expect(meus.single.servico, s1.tipoServico);
      // outro cliente não vê
      expect((await AgendamentoApi(cOutro).meus()).map((m) => m.id), isNot(contains(criado.id)));

      // 3) admin edita horário, serviço e status; manter o mesmo horário não é conflito
      await admin.atualizar(criado.id, data: dia, horario: h1, status: StatusAgendamento.pendente);
      final editado = await admin.atualizar(criado.id, servicoId: s2.id, horario: h2, status: StatusAgendamento.confirmado);
      expect(editado.horario, h2);
      final livresDepois = await agendaCli.disponibilidades(dia);
      expect(livresDepois, contains(h1));
      expect(livresDepois, isNot(contains(h2)));
      await admin.atualizar(criado.id, status: StatusAgendamento.pendente);

      // 4) cliente vê os dados novos
      meus = await agendaCli.meus();
      expect(meus.single.horario, h2);
      expect(meus.single.status, StatusAgendamento.pendente);
      expect(meus.single.servico, s2.tipoServico);

      // conflito na edição: outro agendamento em h3, mover o nosso para h3 → 409
      final outroAg = await admin.criar(clienteId: achado.id, servicoId: s1.id, data: dia, horario: h3);
      await expectLater(admin.atualizar(criado.id, horario: h3), _status(409));
      // o outro cliente não cancela o agendamento deste cliente (404)
      await expectLater(AgendamentoApi(cOutro).cancelar(outroAg.id), _status(404));
      // o próprio cliente cancela o futuro; cancelar de novo → 409
      await agendaCli.cancelar(outroAg.id);
      await expectLater(agendaCli.cancelar(outroAg.id), _status(409));
      await admin.excluir(outroAg.id);

      // 5) admin cancela → cliente vê CANCELADO e o horário fica livre
      await admin.cancelar(criado.id);
      meus = await agendaCli.meus();
      expect(meus.single.id, criado.id);
      expect(meus.single.status, StatusAgendamento.cancelado);
      expect(await agendaCli.disponibilidades(dia), contains(h2));

      // 6) admin exclui → some de /meus e da agenda; excluir de novo → 404
      await admin.excluir(criado.id);
      expect(await agendaCli.meus(), isEmpty);
      expect((await admin.listar(dia)).map((a) => a.id), isNot(contains(criado.id)));
      await expectLater(admin.excluir(criado.id), _status(404));
      await expectLater(admin.atualizar(criado.id, status: StatusAgendamento.confirmado), _status(404));

      // 7) CLIENTE em rota de admin → 403 (todas as rotas novas)
      final adminComoCliente = AdminAgendamentoApi(cCli);
      await expectLater(adminComoCliente.listar(dia), _status(403));
      await expectLater(
          adminComoCliente.criar(clienteId: achado.id, servicoId: s1.id, data: dia, horario: h1), _status(403));
      await expectLater(adminComoCliente.atualizar(1, status: StatusAgendamento.cancelado), _status(403));
      await expectLater(adminComoCliente.excluir(1), _status(403));
      await expectLater(ClientesApi(cCli).buscar('a'), _status(403));
      expect(await agendaCli.disponibilidades(dia), contains(h1), reason: 'nada foi criado pelo cliente');

      // sem token → 401
      final anonimo = AdminAgendamentoApi(cliente(FakeTokenStorage()));
      await expectLater(anonimo.listar(dia), _status(401));
    },
    skip: _baseUrl == null ? 'Defina API_BASE_URL para rodar os testes de contrato' : false,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
