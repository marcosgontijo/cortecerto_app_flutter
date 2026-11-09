// Contrato da FASE 3 contra o backend real: admin cria/edita/cancela/exclui e o cliente vê em /meus.
// Rodar: API_BASE_URL=http://localhost:8080/api ADMIN_CPF=... ADMIN_SENHA=... flutter test --tags contract
// Sem API_BASE_URL o teste é pulado; COM API_BASE_URL e sem ADMIN_* ele FALHA (não pula).
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
import 'package:cortecerto_flutter/features/servicos/data/servicos_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';
import 'fluxo_cliente_contract_test.dart' show cpfAleatorio;

final String? _baseUrl = Platform.environment['API_BASE_URL'];

void main() {
  test(
    'admin cria → cliente vê → admin edita → cliente vê novo → admin cancela → admin exclui → some; '
    'CLIENTE em rota de admin → 403',
    () async {
      final adminCpf = Platform.environment['ADMIN_CPF'];
      final adminSenha = Platform.environment['ADMIN_SENHA'];
      expect(adminCpf, isNotNull, reason: 'defina ADMIN_CPF junto com API_BASE_URL');
      expect(adminSenha, isNotNull, reason: 'defina ADMIN_SENHA junto com API_BASE_URL');

      final r = Random();
      final stAdmin = FakeTokenStorage();
      final stCliente = FakeTokenStorage();
      final cAdmin = ApiClient(tokenStorage: stAdmin, baseUrl: _baseUrl!, onUnauthorized: () async {});
      final cCliente = ApiClient(tokenStorage: stCliente, baseUrl: _baseUrl!, onUnauthorized: () async {});
      final auth = AuthApi(cCliente);

      // cliente novo
      final cpf = cpfAleatorio(r);
      const senha = 'Contrato123';
      await auth.cadastrar(CadastroRequest(
        nome: 'Contrato Fase Tres',
        telefone: '11987654321',
        cpf: cpf,
        email: 'f3.$cpf@teste.local',
        dataNascimento: '1990-03-15',
        senha: senha,
        confirmarSenha: senha,
      ));
      await stCliente.saveToken((await auth.login(cpf: cpf, senha: senha)).token);

      final loginAdmin = await auth.login(cpf: adminCpf!, senha: adminSenha!);
      expect(loginAdmin.usuario.role, 'ADMIN');
      await stAdmin.saveToken(loginAdmin.token);

      final adminApi = AdminAgendamentoApi(cAdmin);
      final clientesApi = ClientesApi(cAdmin);
      final clienteAgenda = AgendamentoApi(cCliente);

      final achados = await clientesApi.buscar(cpf.substring(0, 9));
      final cliente = achados.firstWhere((c) => c.nome == 'Contrato Fase Tres');
      expect(cliente.cpf, '***.***.***-${cpf.substring(9)}');

      final servicos = await ServicosApi(cAdmin).listar();
      final servico = servicos.first;
      final outro = servicos.last;

      final hoje = DateTime.now();
      final dia = DateTime(hoje.year, hoje.month, hoje.day).add(Duration(days: 10 + r.nextInt(300)));
      final livres = await AgendamentoApi(cAdmin).disponibilidades(dia);
      expect(livres.length, greaterThanOrEqualTo(2));

      // admin cria
      final criado = await adminApi.criar(
          clienteId: cliente.id, servicoId: servico.id, data: dia, horario: livres.first);
      expect(criado.status, StatusAgendamento.confirmado);
      expect((await adminApi.listar(dia)).map((a) => a.id), contains(criado.id));

      // cliente vê
      var meus = await clienteAgenda.meus();
      expect(meus.single.id, criado.id);
      expect(meus.single.horario, livres.first);

      // admin edita horário, serviço e status; cliente vê os dados novos
      await adminApi.atualizar(criado.id,
          servicoId: outro.id, data: dia, horario: livres[1], status: StatusAgendamento.pendente);
      meus = await clienteAgenda.meus();
      expect(meus.single.horario, livres[1]);
      expect(meus.single.status, StatusAgendamento.pendente);
      expect(meus.single.servico, outro.tipoServico);

      // admin cancela; cliente vê CANCELADO
      await adminApi.cancelar(criado.id);
      meus = await clienteAgenda.meus();
      expect(meus.single.status, StatusAgendamento.cancelado);

      // admin exclui; some de /meus
      await adminApi.excluir(criado.id);
      expect(await clienteAgenda.meus(), isEmpty);

      // CLIENTE em rota de admin → 403
      await expectLater(
        AdminAgendamentoApi(cCliente).listar(dia),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
      );
      await expectLater(
        ClientesApi(cCliente).buscar('a'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
      );
    },
    skip: _baseUrl == null ? 'Defina API_BASE_URL para rodar os testes de contrato' : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
