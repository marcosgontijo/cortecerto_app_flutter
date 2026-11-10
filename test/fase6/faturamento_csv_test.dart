// FASE 6 (developer): geração do CSV do faturamento (função pura, sem tela): blocos e ordem,
// BOM, `;`, vírgula decimal sem milhar, `\r\n`, dias zerados, serviço vazio, escape, injeção
// de fórmula, nomes de arquivo e acentos em UTF-8.
import 'dart:convert';

import 'package:cortecerto_flutter/features/admin/domain/faturamento.dart';
import 'package:cortecerto_flutter/features/admin/domain/faturamento_csv.dart';
import 'package:cortecerto_flutter/features/admin/domain/periodo_faturamento.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// "Hoje" fixo: 09/11/2026 (segunda-feira).
final hoje = DateTime(2026, 11, 9);

PeriodoFaturamento periodo(TipoPeriodo t, [DateTime? d]) => PeriodoFaturamento.contendo(t, d ?? hoje);

/// Faturamento com todos os dias do período (só o primeiro com valores).
Faturamento fat(PeriodoFaturamento p,
    {List<FaturamentoServico>? servicos,
    int recebido = 123450,
    int realizados = 3,
    int previsto = 0,
    int previstos = 0}) {
  final dias = <FaturamentoDia>[];
  for (var d = p.inicio; !d.isAfter(p.fim); d = DateTime(d.year, d.month, d.day + 1)) {
    dias.add(FaturamentoDia(
      data: d,
      recebidoCentavos: dias.isEmpty ? recebido : 0,
      previstoCentavos: dias.isEmpty ? previsto : 0,
    ));
  }
  return Faturamento(
    inicio: p.inicio,
    fim: p.fim,
    recebidoCentavos: recebido,
    previstoCentavos: previsto,
    quantidadeRealizados: realizados,
    quantidadePrevistos: previstos,
    porDia: dias,
    porServico: servicos ??
        const [
          FaturamentoServico(servico: 'Corte + Barba', quantidade: 2, recebidoCentavos: 100000),
          FaturamentoServico(servico: 'Corte Simples', quantidade: 1, recebidoCentavos: 23450),
        ],
  );
}

List<String> linhas(String texto) {
  expect(texto.endsWith('\r\n'), isTrue, reason: r'toda linha termina com \r\n, inclusive a última');
  return texto.substring(0, texto.length - 2).split('\r\n');
}

List<String> blocos(String texto) => texto.substring(0, texto.length - 2).split('\r\n\r\n');

String linhaServico(String nome) {
  final p = periodo(TipoPeriodo.dia);
  final csv = FaturamentoCsv(
      fat(p, servicos: [FaturamentoServico(servico: nome, quantidade: 1, recebidoCentavos: 3500)]), p);
  return blocos(csv.texto)[3].substring(r'Serviço;Atendimentos;Recebido (R$)'.length + 2);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  group('cabeçalho e blocos', () {
    test('Dia: 4 blocos na ordem, separados por uma linha em branco', () {
      final p = periodo(TipoPeriodo.dia);
      final t = FaturamentoCsv(fat(p), p).texto;
      expect(linhas(t), [
        'Faturamento CorteCerto',
        'Período;09/11/2026',
        'De;09/11/2026;Até;09/11/2026',
        '',
        r'Indicador;Valor (R$);Atendimentos',
        'Recebido;1234,50;3',
        'Previsto;0,00;0',
        '',
        r'Data;Recebido (R$);Previsto (R$)',
        '09/11/2026;1234,50;0,00',
        '',
        r'Serviço;Atendimentos;Recebido (R$)',
        'Corte + Barba;2;1000,00',
        'Corte Simples;1;234,50',
      ]);
      final b = blocos(t);
      expect(b, hasLength(4));
      expect(b[0], startsWith('Faturamento CorteCerto'));
      expect(b[1], startsWith('Indicador;'));
      expect(b[2], startsWith('Data;'));
      expect(b[3], startsWith('Serviço;'));
    });

    test('Semana: rótulo da tela e De/Até; 7 dias inclusive zerados', () {
      final p = periodo(TipoPeriodo.semana);
      final t = FaturamentoCsv(fat(p), p).texto;
      final l = linhas(t);
      expect(l[1], 'Período;09/11 – 15/11/2026');
      expect(l[1], 'Período;${p.rotulo}');
      expect(l[2], 'De;09/11/2026;Até;15/11/2026');
      final dias = blocos(t)[2].split('\r\n');
      expect(dias, hasLength(8));
      expect(dias[2], '10/11/2026;0,00;0,00');
      expect(dias.last, '15/11/2026;0,00;0,00');
    });

    test('Mês: rótulo por extenso, De/Até e 30 linhas de novembro', () {
      final p = periodo(TipoPeriodo.mes);
      final t = FaturamentoCsv(fat(p), p).texto;
      final l = linhas(t);
      expect(l[1], 'Período;novembro de 2026');
      expect(l[2], 'De;01/11/2026;Até;30/11/2026');
      final dias = blocos(t)[2].split('\r\n').skip(1).toList();
      expect(dias, hasLength(30));
      expect(dias.first, startsWith('01/11/2026;'));
      expect(dias.last, '30/11/2026;0,00;0,00');
    });

    test('por dia sai em ordem de data mesmo se vier fora de ordem', () {
      final p = periodo(TipoPeriodo.semana);
      final f = fat(p);
      final embaralhado = Faturamento(
        inicio: f.inicio,
        fim: f.fim,
        recebidoCentavos: f.recebidoCentavos,
        previstoCentavos: f.previstoCentavos,
        quantidadeRealizados: f.quantidadeRealizados,
        quantidadePrevistos: f.quantidadePrevistos,
        porDia: f.porDia.reversed.toList(),
        porServico: f.porServico,
      );
      final datas = blocos(FaturamentoCsv(embaralhado, p).texto)[2]
          .split('\r\n')
          .skip(1)
          .map((l) => l.split(';').first)
          .toList();
      expect(datas, [
        '09/11/2026', '10/11/2026', '11/11/2026', '12/11/2026', '13/11/2026', '14/11/2026', '15/11/2026', //
      ]);
    });

    test('por serviço vazio: linha "Nenhum atendimento realizado neste período"', () {
      final p = periodo(TipoPeriodo.dia);
      final b = blocos(FaturamentoCsv(
              fat(p, servicos: const [], recebido: 0, realizados: 0, previsto: 5500, previstos: 1), p)
          .texto);
      expect(b[1].split('\r\n'), [r'Indicador;Valor (R$);Atendimentos', 'Recebido;0,00;0', 'Previsto;55,00;1']);
      expect(b[3].split('\r\n'), [r'Serviço;Atendimentos;Recebido (R$)', 'Nenhum atendimento realizado neste período']);
    });

    test('por serviço mantém a ordem recebida do servidor', () {
      final p = periodo(TipoPeriodo.dia);
      final b = blocos(FaturamentoCsv(
              fat(p, servicos: const [
                FaturamentoServico(servico: 'B', quantidade: 1, recebidoCentavos: 900),
                FaturamentoServico(servico: 'A', quantidade: 5, recebidoCentavos: 100),
              ]),
              p)
          .texto);
      expect(b[3].split('\r\n').skip(1), ['B;1;9,00', 'A;5;1,00']);
    });
  });

  group('números', () {
    test(r'centavos → vírgula decimal sem milhar e sem R$', () {
      expect(FaturamentoCsv.valor(123450), '1234,50');
      expect(FaturamentoCsv.valor(0), '0,00');
      expect(FaturamentoCsv.valor(5), '0,05');
      expect(FaturamentoCsv.valor(50), '0,50');
      expect(FaturamentoCsv.valor(100000000), '1000000,00');
      expect(FaturamentoCsv.valor(-1250), '-12,50');
    });

    test('do texto da API ("1234.50"/"0.00") ao CSV sem ponto flutuante', () {
      expect(FaturamentoCsv.valor(centavosDe('1234.50')), '1234,50');
      expect(FaturamentoCsv.valor(centavosDe('0.00')), '0,00');
      expect(FaturamentoCsv.valor(centavosDe('9999999.99')), '9999999,99');
    });

    test('valor negativo (gerado pelo app) não ganha a proteção de fórmula', () {
      final p = periodo(TipoPeriodo.dia);
      final l = linhas(FaturamentoCsv(fat(p, recebido: -1250), p).texto);
      expect(l[5], 'Recebido;-12,50;3');
    });
  });

  group('escape e injeção de fórmula', () {
    test('; e " vão entre aspas e " vira ""', () {
      expect(linhaServico('Corte "Premium"; barba'), '"Corte ""Premium""; barba";1;35,00');
    });

    test('quebra de linha no nome vai entre aspas', () {
      expect(linhaServico('Corte\nBarba'), '"Corte\nBarba";1;35,00');
      expect(FaturamentoCsv.campoTexto('a\r\nb'), '"a\r\nb"');
    });

    for (final c in ['=', '+', '-', '@', '\t']) {
      test('nome começando com ${jsonEncode(c)} recebe apóstrofo', () {
        expect(linhaServico('${c}SOMA(A1)'), "'${c}SOMA(A1);1;35,00");
      });
    }

    test(r'nome começando com \r recebe apóstrofo e vai entre aspas', () {
      expect(linhaServico('\rX'), '"\'\rX";1;35,00');
    });

    test('fórmula com ; recebe apóstrofo e aspas', () {
      expect(FaturamentoCsv.campoTexto('=1;2'), '"\'=1;2"');
    });

    test('texto comum não muda', () {
      expect(FaturamentoCsv.campoTexto('Corte + Barba'), 'Corte + Barba');
      expect(FaturamentoCsv.campoTexto(''), '');
    });
  });

  group('nome do arquivo', () {
    test('Dia, Semana e Mês', () {
      for (final (tipo, nome) in [
        (TipoPeriodo.dia, 'faturamento_2026-11-09.csv'),
        (TipoPeriodo.semana, 'faturamento_2026-11-09_a_2026-11-15.csv'),
        (TipoPeriodo.mes, 'faturamento_2026-11.csv'),
      ]) {
        final p = periodo(tipo);
        expect(FaturamentoCsv(fat(p), p).nomeArquivo, nome);
      }
    });

    test('semana que cruza o ano e mês de janeiro com zero à esquerda', () {
      final s = periodo(TipoPeriodo.semana, DateTime(2025, 12, 31));
      expect(FaturamentoCsv(fat(s), s).nomeArquivo, 'faturamento_2025-12-29_a_2026-01-04.csv');
      expect(linhas(FaturamentoCsv(fat(s), s).texto)[1], 'Período;29/12/2025 – 04/01/2026');
      final m = periodo(TipoPeriodo.mes, DateTime(2026, 1, 15));
      expect(FaturamentoCsv(fat(m), m).nomeArquivo, 'faturamento_2026-01.csv');
    });

    test('mime text/csv e assunto com o rótulo do período', () {
      final p = periodo(TipoPeriodo.semana);
      final csv = FaturamentoCsv(fat(p), p);
      expect(FaturamentoCsv.mimeType, 'text/csv');
      expect(csv.assunto, contains('09/11 – 15/11/2026'));
    });
  });

  group('bytes', () {
    test('começam com o BOM EF BB BF e o resto é o texto em UTF-8', () {
      final p = periodo(TipoPeriodo.semana);
      final csv = FaturamentoCsv(fat(p), p);
      final bytes = csv.bytes;
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      final texto = utf8.decode(bytes.sublist(3));
      expect(texto, csv.texto);
      expect(texto, contains('Serviço'));
      expect(texto, contains('Período'));
      expect(texto, contains('Até'));
      // travessão U+2013 em 3 bytes UTF-8
      final corpo = bytes.sublist(3);
      var achou = false;
      for (var i = 0; i + 2 < corpo.length; i++) {
        if (corpo[i] == 0xE2 && corpo[i + 1] == 0x80 && corpo[i + 2] == 0x93) achou = true;
      }
      expect(achou, isTrue);
    });

    test(r'nenhum \n solto: toda quebra é \r\n', () {
      final p = periodo(TipoPeriodo.mes);
      final t = FaturamentoCsv(fat(p), p).texto;
      expect(RegExp(r'(?<!\r)\n').hasMatch(t), isFalse);
    });
  });
}
