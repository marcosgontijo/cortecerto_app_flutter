// Testes de contrato contra o backend real (só Dart + Dio, sem emulador).
// Rodar: API_BASE_URL=http://localhost:8080/api flutter test --tags contract
// Sem API_BASE_URL os testes são pulados (o `flutter test` comum não depende do backend).
@Tags(['contract'])
library;

import 'dart:io';
import 'dart:math';

import 'package:cortecerto_flutter/core/errors/api_exception.dart';
import 'package:cortecerto_flutter/core/network/api_client.dart';
import 'package:cortecerto_flutter/features/agendamento/data/agendamento_api.dart';
import 'package:cortecerto_flutter/features/auth/data/auth_api.dart';
import 'package:cortecerto_flutter/features/auth/domain/auth_models.dart';
import 'package:cortecerto_flutter/features/servicos/data/servicos_api.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

final String? _baseUrl = Platform.environment['API_BASE_URL'];

/// Gera um CPF válido aleatório (evita 409 e bloqueio entre execuções).
String cpfAleatorio(Random r) {
  final d = List<int>.generate(9, (_) => r.nextInt(10));
  int dv(List<int> n) {
    var soma = 0;
    for (var i = 0; i < n.length; i++) {
      soma += n[i] * (n.length + 1 - i);
    }
    final resto = (soma * 10) % 11;
    return resto == 10 ? 0 : resto;
  }

  d.add(dv(d));
  d.add(dv(d));
  if (d.toSet().length == 1) return cpfAleatorio(r);
  return d.join();
}

void main() {
  test(
    'register → login → serviços → disponibilidades → agendar → 409 → 401',
    () async {
      final r = Random();
      final storage = FakeTokenStorage();
      var unauthorized = 0;
      final client = ApiClient(
        tokenStorage: storage,
        baseUrl: _baseUrl!,
        onUnauthorized: () async => unauthorized++,
      );
      final auth = AuthApi(client);
      final servicosApi = ServicosApi(client);
      final agendamentoApi = AgendamentoApi(client);

      final cpf = cpfAleatorio(r);
      const senha = 'Contrato123';
      await auth.cadastrar(CadastroRequest(
        nome: 'Contrato App',
        telefone: '11987654321',
        cpf: cpf,
        email: 'contrato.$cpf@teste.local',
        dataNascimento: '1990-03-15',
        senha: senha,
        confirmarSenha: senha,
      ));

      final login = await auth.login(cpf: cpf, senha: senha);
      expect(login.token, isNotEmpty);
      expect(login.usuario.role, 'CLIENTE');
      await storage.saveToken(login.token);

      final servicos = await servicosApi.listar();
      final nomes = servicos.map((s) => s.tipoServico).toList();
      expect(nomes, containsAll(
          ['Corte Simples', 'Corte + Barba', 'Barba', 'Sobrancelha', 'Corte Completo']));
      final servico = servicos.firstWhere((s) => s.tipoServico == 'Corte Simples');

      // Data futura (o backend recusa passado no fuso de São Paulo).
      final hoje = DateTime.now();
      final dia = DateTime(hoje.year, hoje.month, hoje.day).add(Duration(days: 7 + r.nextInt(300)));
      final horarios = await agendamentoApi.disponibilidades(dia);
      expect(horarios, isNotEmpty);
      final horario = horarios.first;

      await agendamentoApi.agendar(data: dia, horario: horario, servico: servico);
      expect(await agendamentoApi.disponibilidades(dia), isNot(contains(horario)));

      await expectLater(
        agendamentoApi.agendar(data: dia, horario: horario, servico: servico),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
      );

      await storage.saveToken('token.invalido.x');
      await expectLater(
        servicosApi.listar(),
        throwsA(isA<ApiException>().having((e) => e.tipo, 'tipo', ApiErrorTipo.naoAutorizado)),
      );
      expect(unauthorized, 1);
    },
    skip: _baseUrl == null ? 'Defina API_BASE_URL para rodar os testes de contrato' : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
