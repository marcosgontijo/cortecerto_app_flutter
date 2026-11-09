import 'package:intl/intl.dart';

import '../../../core/formatters/formatters.dart';

/// Tipo de período do Faturamento.
enum TipoPeriodo {
  dia('Dia'),
  semana('Semana'),
  mes('Mês');

  const TipoPeriodo(this.rotulo);

  final String rotulo;
}

/// Período do Faturamento (datas sem horário, `inicio` e `fim` incluídos).
///
/// - Dia: só a data.
/// - Semana: de **segunda a domingo**, a que contém a data.
/// - Mês: do dia 1 ao último dia do mês do calendário.
///
/// As contas usam os campos de data (`DateTime(a, m, d ± n)`), nunca `Duration`, para não
/// cair no dia errado numa virada de horário de verão.
class PeriodoFaturamento {
  const PeriodoFaturamento._(this.tipo, this.inicio, this.fim);

  /// Período do [tipo] que contém [data].
  factory PeriodoFaturamento.contendo(TipoPeriodo tipo, DateTime data) {
    final d = DateTime(data.year, data.month, data.day);
    switch (tipo) {
      case TipoPeriodo.dia:
        return PeriodoFaturamento._(tipo, d, d);
      case TipoPeriodo.semana:
        final segunda = DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));
        final domingo = DateTime(segunda.year, segunda.month, segunda.day + 6);
        return PeriodoFaturamento._(tipo, segunda, domingo);
      case TipoPeriodo.mes:
        return PeriodoFaturamento._(tipo, DateTime(d.year, d.month, 1), DateTime(d.year, d.month + 1, 0));
    }
  }

  final TipoPeriodo tipo;
  final DateTime inicio;
  final DateTime fim;

  /// Quantos dias o período tem (as duas pontas incluídas).
  int get dias {
    var n = 0;
    for (var d = inicio; !d.isAfter(fim); d = DateTime(d.year, d.month, d.day + 1)) {
      n++;
    }
    return n;
  }

  /// Período anterior (dia − 1, semana − 7 dias, mês − 1).
  PeriodoFaturamento anterior() => deslocar(-1);

  /// Próximo período (dia + 1, semana + 7 dias, mês + 1).
  PeriodoFaturamento proximo() => deslocar(1);

  PeriodoFaturamento deslocar(int passos) {
    switch (tipo) {
      case TipoPeriodo.dia:
        return PeriodoFaturamento.contendo(tipo, DateTime(inicio.year, inicio.month, inicio.day + passos));
      case TipoPeriodo.semana:
        return PeriodoFaturamento.contendo(tipo, DateTime(inicio.year, inicio.month, inicio.day + 7 * passos));
      case TipoPeriodo.mes:
        return PeriodoFaturamento.contendo(tipo, DateTime(inicio.year, inicio.month + passos, 1));
    }
  }

  /// Rótulo: `09/11/2026`, `03/11 – 09/11/2026` (semana que cruza o ano: `29/12/2025 – 04/01/2026`),
  /// `novembro de 2026`.
  String get rotulo {
    switch (tipo) {
      case TipoPeriodo.dia:
        return Formatters.data(inicio);
      case TipoPeriodo.semana:
        final inicioTexto = inicio.year == fim.year
            ? DateFormat('dd/MM').format(inicio)
            : Formatters.data(inicio);
        return '$inicioTexto – ${Formatters.data(fim)}';
      case TipoPeriodo.mes:
        return DateFormat.yMMMM('pt_BR').format(inicio);
    }
  }

  /// Contém [data] (sem horário)?
  bool contem(DateTime data) {
    final d = DateTime(data.year, data.month, data.day);
    return !d.isBefore(inicio) && !d.isAfter(fim);
  }

  @override
  bool operator ==(Object other) =>
      other is PeriodoFaturamento && other.tipo == tipo && other.inicio == inicio && other.fim == fim;

  @override
  int get hashCode => Object.hash(tipo, inicio, fim);

  @override
  String toString() => 'PeriodoFaturamento($tipo, $inicio..$fim)';
}
