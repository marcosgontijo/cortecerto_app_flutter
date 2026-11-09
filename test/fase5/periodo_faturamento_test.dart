// FASE 5 (developer): período do Faturamento (Dia / Semana seg–dom / Mês), navegação e rótulo.
import 'package:cortecerto_flutter/features/admin/domain/periodo_faturamento.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  PeriodoFaturamento p(TipoPeriodo t, int a, int m, int d) => PeriodoFaturamento.contendo(t, DateTime(a, m, d));

  group('Dia', () {
    test('é só a data (sem horário) e o rótulo é dd/MM/aaaa', () {
      final dia = PeriodoFaturamento.contendo(TipoPeriodo.dia, DateTime(2026, 11, 9, 23, 59));
      expect(dia.inicio, DateTime(2026, 11, 9));
      expect(dia.fim, DateTime(2026, 11, 9));
      expect(dia.dias, 1);
      expect(dia.rotulo, '09/11/2026');
    });

    test('anterior/próximo = dia − 1 / + 1, inclusive na virada de mês e ano', () {
      expect(p(TipoPeriodo.dia, 2026, 11, 9).proximo().inicio, DateTime(2026, 11, 10));
      expect(p(TipoPeriodo.dia, 2026, 11, 9).anterior().inicio, DateTime(2026, 11, 8));
      expect(p(TipoPeriodo.dia, 2026, 12, 31).proximo().inicio, DateTime(2027, 1, 1));
      expect(p(TipoPeriodo.dia, 2028, 3, 1).anterior().inicio, DateTime(2028, 2, 29));
    });
  });

  group('Semana (segunda a domingo que contém a data)', () {
    test('09/11/2026 é segunda: semana 09/11 – 15/11/2026', () {
      expect(DateTime(2026, 11, 9).weekday, DateTime.monday);
      final s = p(TipoPeriodo.semana, 2026, 11, 9);
      expect(s.inicio, DateTime(2026, 11, 9));
      expect(s.fim, DateTime(2026, 11, 15));
      expect(s.dias, 7);
      expect(s.rotulo, '09/11 – 15/11/2026');
    });

    test('qualquer dia da semana cai na mesma semana (quarta 05/11 e domingo 08/11 → 02/11..08/11)', () {
      for (final d in [2, 3, 4, 5, 6, 7, 8]) {
        final s = p(TipoPeriodo.semana, 2026, 11, d);
        expect(s.inicio, DateTime(2026, 11, 2), reason: '$d/11');
        expect(s.fim, DateTime(2026, 11, 8), reason: '$d/11');
        expect(s.inicio.weekday, DateTime.monday);
        expect(s.fim.weekday, DateTime.sunday);
      }
      expect(p(TipoPeriodo.semana, 2026, 11, 5).rotulo, '02/11 – 08/11/2026');
    });

    test('semana que cruza o mês e o ano', () {
      final virada = p(TipoPeriodo.semana, 2025, 12, 31);
      expect(virada.inicio, DateTime(2025, 12, 29));
      expect(virada.fim, DateTime(2026, 1, 4));
      expect(virada.rotulo, '29/12/2025 – 04/01/2026');
      final mes = p(TipoPeriodo.semana, 2026, 10, 1);
      expect(mes.inicio, DateTime(2026, 9, 28));
      expect(mes.fim, DateTime(2026, 10, 4));
      expect(mes.rotulo, '28/09 – 04/10/2026');
    });

    test('anterior/próximo deslocam 7 dias', () {
      final s = p(TipoPeriodo.semana, 2026, 11, 9);
      expect(s.proximo().inicio, DateTime(2026, 11, 16));
      expect(s.proximo().fim, DateTime(2026, 11, 22));
      expect(s.anterior().inicio, DateTime(2026, 11, 2));
      expect(s.anterior().fim, DateTime(2026, 11, 8));
    });

    test('virada de horário de verão não quebra a semana (out/2018 no Brasil)', () {
      // 04/11/2018: início do horário de verão em SP no calendário antigo; as contas usam campos de data
      final s = p(TipoPeriodo.semana, 2018, 11, 4);
      expect(s.inicio, DateTime(2018, 10, 29));
      expect(s.fim, DateTime(2018, 11, 4));
      expect(s.dias, 7);
    });
  });

  group('Mês (mês do calendário)', () {
    test('novembro de 2026: 01..30, rótulo por extenso em pt-BR', () {
      final m = p(TipoPeriodo.mes, 2026, 11, 9);
      expect(m.inicio, DateTime(2026, 11, 1));
      expect(m.fim, DateTime(2026, 11, 30));
      expect(m.dias, 30);
      expect(m.rotulo, 'novembro de 2026');
    });

    test('fevereiro bissexto e não bissexto; meses de 31 dias', () {
      expect(p(TipoPeriodo.mes, 2028, 2, 10).fim, DateTime(2028, 2, 29));
      expect(p(TipoPeriodo.mes, 2028, 2, 10).dias, 29);
      expect(p(TipoPeriodo.mes, 2026, 2, 10).fim, DateTime(2026, 2, 28));
      expect(p(TipoPeriodo.mes, 2026, 12, 31).fim, DateTime(2026, 12, 31));
      expect(p(TipoPeriodo.mes, 2026, 12, 31).dias, 31);
    });

    test('anterior/próximo = mês − 1 / + 1, atravessando o ano', () {
      expect(p(TipoPeriodo.mes, 2026, 12, 15).proximo().inicio, DateTime(2027, 1, 1));
      expect(p(TipoPeriodo.mes, 2026, 1, 31).anterior().inicio, DateTime(2025, 12, 1));
      expect(p(TipoPeriodo.mes, 2026, 1, 31).proximo().fim, DateTime(2026, 2, 28));
      expect(p(TipoPeriodo.mes, 2026, 1, 31).proximo().rotulo, 'fevereiro de 2026');
    });
  });

  test('contem() considera as duas pontas', () {
    final s = p(TipoPeriodo.semana, 2026, 11, 9);
    expect(s.contem(DateTime(2026, 11, 9)), isTrue);
    expect(s.contem(DateTime(2026, 11, 15, 23, 59)), isTrue);
    expect(s.contem(DateTime(2026, 11, 8)), isFalse);
    expect(s.contem(DateTime(2026, 11, 16)), isFalse);
  });
}
