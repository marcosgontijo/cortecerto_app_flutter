// Contrato da FASE 5 contra o backend real: admin cria → marca REALIZADO → o faturamento do dia mostra o
// valor em "recebido"; um CONFIRMADO aparece em "previsto"; um CANCELADO não aparece; CLIENTE → 403.
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
import 'package:cortecerto_flutter/features/admin/domain/faturamento.dart';
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
    'REALIZADO em recebido, CONFIRMADO em previsto, CANCELADO fora; CLIENTE no faturamento → 403',
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

      final cpf = cpfAleatorio(r);
      const senha = 'Contrato123';
      await auth.cadastrar(CadastroRequest(
        nome: 'Contrato Fase Cinco',
        telefone: '11987654321',
        cpf: cpf,
        email: 'f5.$cpf@teste.local',
        dataNascimento: '1990-03-15',
        senha: senha,
        confirmarSenha: senha,
      ));
      await stCliente.saveToken((await auth.login(cpf: cpf, senha: senha)).token);
      final loginAdmin = await auth.login(cpf: adminCpf!, senha: adminSenha!);
      expect(loginAdmin.usuario.role, 'ADMIN');
      await stAdmin.saveToken(loginAdmin.token);

      final adminApi = AdminAgendamentoApi(cAdmin);
      final cliente = (await ClientesApi(cAdmin).buscar(cpf.substring(0, 9)))
          .firstWhere((c) => c.nome == 'Contrato Fase Cinco');
      final servicos = await ServicosApi(cAdmin).listar();
      expect(servicos.length, greaterThanOrEqualTo(2));
      final servicoA = servicos.first;
      final servicoB = servicos[1];
      final precoA = centavosDe(servicoA.precoServico);
      final precoB = centavosDe(servicoB.precoServico);
      expect(precoA, greaterThan(0));
      expect(precoB, greaterThan(0));

      // Dia fora da faixa dos outros contratos (+7 a +310 dias), que rodam em paralelo; confere que
      // o dia está vazio (24 livres) para as somas não serem contaminadas.
      final hoje = DateTime.now();
      DateTime? dia;
      for (var tentativa = 0; tentativa < 10 && dia == null; tentativa++) {
        final d = DateTime(hoje.year, hoje.month, hoje.day + 320 + r.nextInt(80));
        if ((await AgendamentoApi(cAdmin).disponibilidades(d)).length == 24) dia = d;
      }
      expect(dia, isNotNull, reason: 'nenhum dia livre encontrado');
      final livres = await AgendamentoApi(cAdmin).disponibilidades(dia!);

      final antes = await adminApi.faturamento(dia, dia);
      expect(antes.recebidoCentavos, 0);
      expect(antes.previstoCentavos, 0);

      // 1) REALIZADO
      final realizado = await adminApi.criar(
          clienteId: cliente.id, servicoId: servicoA.id, data: dia, horario: livres[0]);
      await adminApi.atualizar(realizado.id, status: StatusAgendamento.realizado);
      // 2) CONFIRMADO
      final confirmado = await adminApi.criar(
          clienteId: cliente.id, servicoId: servicoB.id, data: dia, horario: livres[1]);
      // 3) CANCELADO
      final cancelado = await adminApi.criar(
          clienteId: cliente.id, servicoId: servicoA.id, data: dia, horario: livres[2]);
      await adminApi.cancelar(cancelado.id);

      final f = await adminApi.faturamento(dia, dia);
      expect(f.inicio, dia);
      expect(f.fim, dia);
      expect(f.recebidoCentavos, precoA, reason: 'REALIZADO soma no recebido (e o CANCELADO não)');
      expect(f.quantidadeRealizados, 1);
      expect(f.previstoCentavos, precoB, reason: 'CONFIRMADO soma no previsto');
      expect(f.quantidadePrevistos, 1);
      expect(f.porDia, hasLength(1));
      expect(f.porDia.single.data, dia);
      expect(f.porDia.single.recebidoCentavos, precoA);
      expect(f.porDia.single.previstoCentavos, precoB);
      expect(f.porServico, hasLength(1));
      expect(f.porServico.single.servico, servicoA.tipoServico);
      expect(f.porServico.single.quantidade, 1);
      expect(f.porServico.single.recebidoCentavos, precoA);

      // semana inteira em volta do dia: o dia aparece com o mesmo valor e os outros zerados
      final semana = await adminApi.faturamento(
          DateTime(dia.year, dia.month, dia.day - 3), DateTime(dia.year, dia.month, dia.day + 3));
      expect(semana.porDia, hasLength(7));
      expect(semana.porDia[3].recebidoCentavos, precoA);

      // CLIENTE no faturamento → 403
      await expectLater(
        AdminAgendamentoApi(cCliente).faturamento(dia, dia),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
      );

      // limpeza
      for (final id in [realizado.id, confirmado.id, cancelado.id]) {
        await adminApi.excluir(id);
      }
      final depois = await adminApi.faturamento(dia, dia);
      expect(depois.recebidoCentavos, 0);
      expect(depois.previstoCentavos, 0);
    },
    skip: _baseUrl == null ? 'Defina API_BASE_URL para rodar os testes de contrato' : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
