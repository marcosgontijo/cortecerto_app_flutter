// FASE 6 (tester): CSV do faturamento, casos que os testes do developer não cobriam.
// - leitura de volta com um parser CSV (RFC 4180, separador `;`): prova que o escape não quebra colunas
//   e que o Excel veria exatamente o texto esperado (com o `'` da proteção de fórmula);
// - estrutura fechada (nenhuma linha além dos 4 blocos: sem espaço para dado pessoal);
// - caminho completo texto da API ("1234.50") -> Faturamento.fromJson -> CSV;
// - números nunca com `.`/`'`, fevereiro bissexto, semana que cruza o mês, BOM uma única vez.
import 'dart:convert';

import 'package:cortecerto_flutter/features/admin/domain/faturamento.dart';
import 'package:cortecerto_flutter/features/admin/domain/faturamento_csv.dart';
import 'package:cortecerto_flutter/features/admin/domain/periodo_faturamento.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

final hoje = DateTime(2026, 11, 9);

/// Parser CSV mínimo (RFC 4180 com `;` e `\r\n`), como o Excel faz: campo entre aspas pode ter
/// `;`, `\r`, `\n` e `""` (aspas escapadas). Lança se as aspas estiverem desbalanceadas.
List<List<String>> lerCsv(String texto) {
  final registros = <List<String>>[];
  var campo = StringBuffer();
  var registro = <String>[];
  var i = 0;
  var entreAspas = false;
  var campoComAspas = false;
  while (i < texto.length) {
    final c = texto[i];
    if (entreAspas) {
      if (c == '"') {
        if (i + 1 < texto.length && texto[i + 1] == '"') {
          campo.write('"');
          i += 2;
          continue;
        }
        entreAspas = false;
        i++;
        continue;
      }
      campo.write(c);
      i++;
      continue;
    }
    if (c == '"') {
      if (campo.isNotEmpty) throw FormatException('aspas no meio do campo', texto, i);
      entreAspas = true;
      campoComAspas = true;
      i++;
    } else if (c == ';') {
      registro.add(campo.toString());
      campo = StringBuffer();
      campoComAspas = false;
      i++;
    } else if (c == '\r' && i + 1 < texto.length && texto[i + 1] == '\n') {
      registro.add(campo.toString());
      registros.add(registro);
      registro = <String>[];
      campo = StringBuffer();
      campoComAspas = false;
      i += 2;
    } else if (c == '\r' || c == '\n') {
      throw FormatException('quebra de linha solta fora de aspas', texto, i);
    } else {
      if (campoComAspas) throw FormatException('texto depois das aspas de fechamento', texto, i);
      campo.write(c);
      i++;
    }
  }
  if (entreAspas) throw const FormatException('aspas não fechadas');
  if (campo.isNotEmpty || registro.isNotEmpty) {
    throw const FormatException(r'última linha sem \r\n');
  }
  return registros;
}

Faturamento fatCom(PeriodoFaturamento p, List<FaturamentoServico> servicos) {
  final dias = <FaturamentoDia>[];
  for (var d = p.inicio; !d.isAfter(p.fim); d = DateTime(d.year, d.month, d.day + 1)) {
    dias.add(FaturamentoDia(data: d, recebidoCentavos: 0, previstoCentavos: 0));
  }
  return Faturamento(
    inicio: p.inicio,
    fim: p.fim,
    recebidoCentavos: 0,
    previstoCentavos: 0,
    quantidadeRealizados: 0,
    quantidadePrevistos: 0,
    porDia: dias,
    porServico: servicos,
  );
}

final numero = RegExp(r'^-?\d+,\d{2}$');
final data = RegExp(r'^\d{2}/\d{2}/\d{4}$');

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  test('leitura de volta: nomes hostis de serviço viram exatamente 3 colunas com o texto esperado', () {
    // nome do banco -> o que o Excel deve mostrar na célula
    const casos = <String, String>{
      'Corte "Premium"; barba': 'Corte "Premium"; barba',
      'Linha\nquebrada': 'Linha\nquebrada',
      'CR\r\nLF': 'CR\r\nLF',
      '=HYPERLINK("http://x";"clique")': '\'=HYPERLINK("http://x";"clique")',
      '+5511999': "'+5511999",
      '-1+1': "'-1+1",
      '@SOMA(A1)': "'@SOMA(A1)",
      '\tTAB': "'\tTAB",
      '\r=1': "'\r=1",
      'Ação; ç "ã"': 'Ação; ç "ã"',
      'Corte=Barba': 'Corte=Barba',
      '""': '""',
      ';': ';',
    };
    final p = PeriodoFaturamento.contendo(TipoPeriodo.dia, hoje);
    final servicos = [
      for (final nome in casos.keys) FaturamentoServico(servico: nome, quantidade: 7, recebidoCentavos: 123456),
    ];
    final registros = lerCsv(FaturamentoCsv(fatCom(p, servicos), p).texto);
    final cab = registros.indexWhere((r) => r.isNotEmpty && r.first == 'Serviço');
    expect(cab, greaterThan(0));
    final linhasServico = registros.sublist(cab + 1);
    expect(linhasServico, hasLength(casos.length));
    var i = 0;
    for (final esperado in casos.values) {
      expect(linhasServico[i], [esperado, '7', '1234,56'], reason: 'serviço #$i (${jsonEncode(casos.keys.elementAt(i))})');
      i++;
    }
  });

  test('estrutura fechada: colunas por linha e nenhuma linha fora dos 4 blocos (Semana com 2 serviços)', () {
    final p = PeriodoFaturamento.contendo(TipoPeriodo.semana, hoje);
    final f = fatCom(p, const [
      FaturamentoServico(servico: 'A', quantidade: 1, recebidoCentavos: 100),
      FaturamentoServico(servico: 'B', quantidade: 2, recebidoCentavos: 50),
    ]);
    final r = lerCsv(FaturamentoCsv(f, p).texto);
    // 3 cabeçalho + 1 + 3 resumo + 1 + (1 + 7 dias) + 1 + (1 + 2 serviços)
    expect(r, hasLength(3 + 1 + 3 + 1 + 8 + 1 + 3));
    final colunas = r.map((l) => l.length == 1 && l.single.isEmpty ? 0 : l.length).toList();
    expect(colunas, [1, 2, 4, 0, 3, 3, 3, 0, 3, 3, 3, 3, 3, 3, 3, 3, 0, 3, 3, 3]);
  });

  test('do JSON da API (texto "1234.50") até o CSV: valores e datas sem ponto flutuante', () {
    final f = Faturamento.fromJson({
      'inicio': '2026-11-09',
      'fim': '2026-11-09',
      'recebido': '1234.50',
      'previsto': '0.00',
      'quantidadeRealizados': 3,
      'quantidadePrevistos': 0,
      'porDia': [
        {'data': '2026-11-09', 'recebido': '1234.50', 'previsto': '0.00'},
      ],
      'porServico': [
        {'servico': 'Corte', 'quantidade': 3, 'recebido': '1234.50'},
      ],
    });
    final p = PeriodoFaturamento.contendo(TipoPeriodo.dia, hoje);
    final r = lerCsv(FaturamentoCsv(f, p).texto);
    expect(r[5], ['Recebido', '1234,50', '3']);
    expect(r[6], ['Previsto', '0,00', '0']);
    expect(r[9], ['09/11/2026', '1234,50', '0,00']);
    expect(r[12], ['Corte', '3', '1234,50']);
  });

  test("números e datas gerados pelo app: sempre 1234,50 / dd/MM/yyyy, nunca com '.' nem apóstrofo", () {
    final p = PeriodoFaturamento.contendo(TipoPeriodo.mes, hoje);
    final base = fatCom(p, const [
      FaturamentoServico(servico: 'X', quantidade: 1000000, recebidoCentavos: 99999999999),
      FaturamentoServico(servico: 'Y', quantidade: 0, recebidoCentavos: -1),
    ]);
    final f = Faturamento(
      inicio: base.inicio,
      fim: base.fim,
      recebidoCentavos: 123456789012,
      previstoCentavos: -5,
      quantidadeRealizados: 1000000,
      quantidadePrevistos: 0,
      porDia: base.porDia,
      porServico: base.porServico,
    );
    final r = lerCsv(FaturamentoCsv(f, p).texto);
    expect(r[5], ['Recebido', '1234567890,12', '1000000']);
    expect(r[6], ['Previsto', '-0,05', '0']);
    final dias = r.sublist(9, 9 + 30);
    for (final d in dias) {
      expect(d[0], matches(data));
      expect(d[1], matches(numero));
      expect(d[2], matches(numero));
    }
    final serv = r.sublist(r.length - 2);
    expect(serv[0], ['X', '1000000', '999999999,99']);
    expect(serv[1], ['Y', '0', '-0,01']);
  });

  test('fevereiro bissexto (2028): 29 dias, De/Até e nome faturamento_2028-02.csv', () {
    final p = PeriodoFaturamento.contendo(TipoPeriodo.mes, DateTime(2028, 2, 10));
    final csv = FaturamentoCsv(fatCom(p, const []), p);
    final r = lerCsv(csv.texto);
    expect(r[1], ['Período', 'fevereiro de 2028']);
    expect(r[2], ['De', '01/02/2028', 'Até', '29/02/2028']);
    final dias = r.sublist(9).takeWhile((l) => !(l.length == 1 && l.single.isEmpty)).toList();
    expect(dias, hasLength(29));
    expect(dias.last, ['29/02/2028', '0,00', '0,00']);
    expect(csv.nomeArquivo, 'faturamento_2028-02.csv');
  });

  test('semana que cruza o mês (30/11 a 06/12/2026): nome e rótulo', () {
    final p = PeriodoFaturamento.contendo(TipoPeriodo.semana, DateTime(2026, 12, 2));
    final csv = FaturamentoCsv(fatCom(p, const []), p);
    expect(csv.nomeArquivo, 'faturamento_2026-11-30_a_2026-12-06.csv');
    final r = lerCsv(csv.texto);
    expect(r[1], ['Período', p.rotulo]);
    expect(r[2], ['De', '30/11/2026', 'Até', '06/12/2026']);
    expect(csv.assunto, contains(p.rotulo));
  });

  test('BOM só uma vez (no início dos bytes, nunca dentro do texto)', () {
    final p = PeriodoFaturamento.contendo(TipoPeriodo.dia, hoje);
    final csv = FaturamentoCsv(fatCom(p, const []), p);
    expect(csv.texto.startsWith('﻿'), isFalse);
    expect(csv.texto.contains('﻿'), isFalse);
    expect(csv.bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    expect(csv.bytes.sublist(3, 6), isNot([0xEF, 0xBB, 0xBF]));
    expect(csv.bytes.length, 3 + utf8.encode(csv.texto).length);
  });

  test('determinístico: duas gerações iguais e não altera a lista porDia original', () {
    final p = PeriodoFaturamento.contendo(TipoPeriodo.semana, hoje);
    final f0 = fatCom(p, const []);
    final f = Faturamento(
      inicio: f0.inicio,
      fim: f0.fim,
      recebidoCentavos: 0,
      previstoCentavos: 0,
      quantidadeRealizados: 0,
      quantidadePrevistos: 0,
      porDia: f0.porDia.reversed.toList(),
      porServico: const [],
    );
    final antes = f.porDia.map((d) => d.data).toList();
    final a = FaturamentoCsv(f, p).texto;
    final b = FaturamentoCsv(f, p).texto;
    expect(a, b);
    expect(f.porDia.map((d) => d.data).toList(), antes, reason: 'a tela usa a mesma lista: o CSV não pode reordená-la');
  });
}
