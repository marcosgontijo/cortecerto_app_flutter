// FASE 5 (developer): modelo Faturamento (texto → centavos sem double) e AdminAgendamentoApi.faturamento.
import 'package:cortecerto_flutter/core/errors/api_exception.dart';
import 'package:cortecerto_flutter/core/network/api_client.dart';
import 'package:cortecerto_flutter/features/admin/data/admin_agendamento_api.dart';
import 'package:cortecerto_flutter/features/admin/domain/faturamento.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

Map<String, dynamic> respostaExemplo() => {
      'inicio': '2026-11-09',
      'fim': '2026-11-10',
      'recebido': '1234.50',
      'previsto': '55.00',
      'quantidadeRealizados': 3,
      'quantidadePrevistos': 1,
      'porDia': [
        {'data': '2026-11-09', 'recebido': '1234.50', 'previsto': '0.00'},
        {'data': '2026-11-10', 'recebido': '0.00', 'previsto': '55.00'},
      ],
      'porServico': [
        {'servico': 'Corte + Barba', 'quantidade': 2, 'recebido': '1199.50'},
        {'servico': 'Corte Simples', 'quantidade': 1, 'recebido': '35.00'},
      ],
    };

void main() {
  group('centavosDe', () {
    test('texto do backend → centavos exatos', () {
      expect(centavosDe('1234.50'), 123450);
      expect(centavosDe('0.00'), 0);
      expect(centavosDe('35.00'), 3500);
      expect(centavosDe('0.29'), 29);
      expect(centavosDe('19.99'), 1999);
      expect(centavosDe('35'), 3500);
      expect(centavosDe('7.5'), 750);
      expect(centavosDe(' 12,34 '), 1234);
    });

    test('número também é aceito (tolerância de formato)', () {
      expect(centavosDe(35), 3500);
      expect(centavosDe(35.5), 3550);
      expect(centavosDe(0.29), 29);
    });

    test('ausente ou inválido → 0', () {
      for (final v in [null, '', 'abc', '1.2.3', 'R\$ 3,00', '35.123']) {
        expect(centavosDe(v), 0, reason: '$v');
      }
    });
  });

  test('Faturamento.fromJson lê todos os campos', () {
    final f = Faturamento.fromJson(respostaExemplo());
    expect(f.inicio, DateTime(2026, 11, 9));
    expect(f.fim, DateTime(2026, 11, 10));
    expect(f.recebidoCentavos, 123450);
    expect(f.previstoCentavos, 5500);
    expect(f.quantidadeRealizados, 3);
    expect(f.quantidadePrevistos, 1);
    expect(f.porDia, hasLength(2));
    expect(f.porDia[1].data, DateTime(2026, 11, 10));
    expect(f.porDia[1].previstoCentavos, 5500);
    expect(f.maiorRecebidoDia, 123450);
    expect(f.porServico.map((s) => s.servico), ['Corte + Barba', 'Corte Simples']);
    expect(f.porServico.first.quantidade, 2);
    expect(f.porServico.first.recebidoCentavos, 119950);
    expect(f.semRealizados, isFalse);
  });

  test('Faturamento.fromJson tolera listas ausentes', () {
    final f = Faturamento.fromJson({'inicio': '2026-11-09', 'fim': '2026-11-09', 'recebido': '0.00'});
    expect(f.porDia, isEmpty);
    expect(f.porServico, isEmpty);
    expect(f.semRealizados, isTrue);
    expect(f.maiorRecebidoDia, 0);
  });

  group('AdminAgendamentoApi.faturamento', () {
    test('GET /agendamento/admin/faturamento com inicio e fim AAAA-MM-DD', () async {
      final adapter = FakeHttpAdapter((_) => jsonResponse(respostaExemplo(), 200));
      final api = AdminAgendamentoApi(ApiClient(
        tokenStorage: FakeTokenStorage('tok'),
        onUnauthorized: () async {},
        baseUrl: 'http://x/api',
        httpClientAdapter: adapter,
      ));
      final f = await api.faturamento(DateTime(2026, 11, 9), DateTime(2026, 11, 15, 22));
      expect(f.recebidoCentavos, 123450);
      final r = adapter.requisicoes.single;
      expect(r.method, 'GET');
      expect(r.path, '/agendamento/admin/faturamento');
      expect(r.queryParameters, {'inicio': '2026-11-09', 'fim': '2026-11-15'});
      expect(r.headers['Authorization'], 'Bearer tok');
    });

    test('403 vira ApiException com a mensagem do backend', () async {
      final adapter = FakeHttpAdapter((_) => jsonResponse({'status': 403, 'message': 'Acesso negado'}, 403));
      final api = AdminAgendamentoApi(ApiClient(
        tokenStorage: FakeTokenStorage('tok'),
        onUnauthorized: () async {},
        baseUrl: 'http://x/api',
        httpClientAdapter: adapter,
      ));
      await expectLater(api.faturamento(DateTime(2026, 11, 9), DateTime(2026, 11, 9)), throwsA(isA<ApiException>()));
    });
  });
}
