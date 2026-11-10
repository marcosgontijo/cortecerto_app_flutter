import 'dart:convert';
import 'dart:typed_data';

import '../../../core/formatters/formatters.dart';
import 'faturamento.dart';
import 'periodo_faturamento.dart';

/// CSV do Faturamento (FASE 6), gerado no próprio app a partir do [Faturamento] que a tela
/// já carregou. Pensado para abrir direto no Excel em português:
///
/// - UTF-8 **com BOM** (`EF BB BF`), separador `;`, quebra de linha `\r\n` (inclusive na última);
/// - valores com vírgula decimal e **sem** separador de milhar (`1234,50`), feitos com
///   aritmética inteira sobre os centavos (nada de ponto flutuante);
/// - datas `dd/MM/yyyy`;
/// - campos de texto escapados (`;`, `"`, `\r`, `\n` → entre aspas, `"` → `""`) e protegidos
///   contra injeção de fórmula (começa com `=`, `+`, `-`, `@`, tab ou `\r` → ganha `'` na frente).
///
/// Função pura: não depende de widgets, do contexto da tela nem de I/O.
class FaturamentoCsv {
  const FaturamentoCsv(this.faturamento, this.periodo);

  final Faturamento faturamento;

  /// Período exibido na tela (rótulo, `De` e `Até` e nome do arquivo saem daqui).
  final PeriodoFaturamento periodo;

  static const String mimeType = 'text/csv';
  static const String separador = ';';
  static const String quebra = '\r\n';
  static const List<int> bom = [0xEF, 0xBB, 0xBF];
  static const String semServicos = 'Nenhum atendimento realizado neste período';

  /// Assunto/título da folha de compartilhamento.
  String get assunto => 'Faturamento CorteCerto - ${periodo.rotulo}';

  /// Dia `faturamento_2026-11-09.csv`, Semana `faturamento_2026-11-09_a_2026-11-15.csv`,
  /// Mês `faturamento_2026-11.csv`.
  String get nomeArquivo {
    switch (periodo.tipo) {
      case TipoPeriodo.dia:
        return 'faturamento_${Formatters.dataApi(periodo.inicio)}.csv';
      case TipoPeriodo.semana:
        return 'faturamento_${Formatters.dataApi(periodo.inicio)}_a_${Formatters.dataApi(periodo.fim)}.csv';
      case TipoPeriodo.mes:
        final mes = periodo.inicio.month.toString().padLeft(2, '0');
        final ano = periodo.inicio.year.toString().padLeft(4, '0');
        return 'faturamento_$ano-$mes.csv';
    }
  }

  /// Texto do CSV (sem o BOM): 4 blocos separados por uma linha em branco.
  String get texto {
    final f = faturamento;
    final linhas = <List<String>>[
      // 1. Cabeçalho
      [_texto('Faturamento CorteCerto')],
      [_texto('Período'), _texto(periodo.rotulo)],
      [_texto('De'), _data(periodo.inicio), _texto('Até'), _data(periodo.fim)],
      const [],
      // 2. Resumo
      [_texto('Indicador'), _texto(r'Valor (R$)'), _texto('Atendimentos')],
      [_texto('Recebido'), valor(f.recebidoCentavos), _inteiro(f.quantidadeRealizados)],
      [_texto('Previsto'), valor(f.previstoCentavos), _inteiro(f.quantidadePrevistos)],
      const [],
      // 3. Por dia (todos os dias, inclusive zerados, em ordem de data)
      [_texto('Data'), _texto(r'Recebido (R$)'), _texto(r'Previsto (R$)')],
      for (final d in [...f.porDia]..sort((a, b) => a.data.compareTo(b.data)))
        [_data(d.data), valor(d.recebidoCentavos), valor(d.previstoCentavos)],
      const [],
      // 4. Por serviço (na ordem do servidor: recebido decrescente)
      [_texto('Serviço'), _texto('Atendimentos'), _texto(r'Recebido (R$)')],
      if (f.porServico.isEmpty)
        [_texto(semServicos)]
      else
        for (final s in f.porServico)
          [_texto(s.servico), _inteiro(s.quantidade), valor(s.recebidoCentavos)],
    ];
    final b = StringBuffer();
    for (final l in linhas) {
      b
        ..write(l.join(separador))
        ..write(quebra);
    }
    return b.toString();
  }

  /// Bytes do arquivo: BOM UTF-8 + texto em UTF-8.
  Uint8List get bytes => Uint8List.fromList([...bom, ...utf8.encode(texto)]);

  /// Centavos → `1234,50` (vírgula decimal, sem milhar, sem `R$`), só com aritmética inteira.
  /// Negativo sai `-12,50` (número gerado pelo app: não recebe a proteção de fórmula).
  static String valor(int centavos) {
    final negativo = centavos < 0;
    final absoluto = negativo ? -centavos : centavos;
    final reais = absoluto ~/ 100;
    final resto = (absoluto % 100).toString().padLeft(2, '0');
    return '${negativo ? '-' : ''}$reais,$resto';
  }

  /// Campo de texto (rótulos fixos, rótulo do período e nome do serviço, que vem do banco):
  /// proteção contra injeção de fórmula e escape CSV.
  static String campoTexto(String valor) {
    var v = valor;
    if (v.isNotEmpty && const ['=', '+', '-', '@', '\t', '\r'].contains(v[0])) {
      v = "'$v";
    }
    if (v.contains(separador) || v.contains('"') || v.contains('\r') || v.contains('\n')) {
      v = '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static String _texto(String v) => campoTexto(v);

  static String _inteiro(int n) => n.toString();

  static String _data(DateTime d) => Formatters.data(d);
}
