/// Faturamento do admin (`GET /agendamento/admin/faturamento`). Os valores chegam em texto
/// `"1234.50"` e ficam em **centavos inteiros** no app (nada de soma em ponto flutuante);
/// só a exibição divide por 100.
class Faturamento {
  const Faturamento({
    required this.inicio,
    required this.fim,
    required this.recebidoCentavos,
    required this.previstoCentavos,
    required this.quantidadeRealizados,
    required this.quantidadePrevistos,
    this.porDia = const [],
    this.porServico = const [],
  });

  final DateTime inicio;
  final DateTime fim;

  /// Soma dos REALIZADO do período.
  final int recebidoCentavos;

  /// Soma dos CONFIRMADO e PENDENTE do período.
  final int previstoCentavos;
  final int quantidadeRealizados;
  final int quantidadePrevistos;
  final List<FaturamentoDia> porDia;
  final List<FaturamentoServico> porServico;

  /// Nenhum atendimento realizado no período (o previsto pode ser maior que zero).
  bool get semRealizados => quantidadeRealizados == 0;

  /// Maior recebido entre os dias (base da barra proporcional).
  int get maiorRecebidoDia =>
      porDia.fold(0, (m, d) => d.recebidoCentavos > m ? d.recebidoCentavos : m);

  factory Faturamento.fromJson(Map<String, dynamic> json) => Faturamento(
        inicio: _data(json['inicio']),
        fim: _data(json['fim']),
        recebidoCentavos: centavosDe(json['recebido']),
        previstoCentavos: centavosDe(json['previsto']),
        quantidadeRealizados: _inteiro(json['quantidadeRealizados']),
        quantidadePrevistos: _inteiro(json['quantidadePrevistos']),
        porDia: (json['porDia'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(FaturamentoDia.fromJson)
            .toList(),
        porServico: (json['porServico'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(FaturamentoServico.fromJson)
            .toList(),
      );
}

class FaturamentoDia {
  const FaturamentoDia({required this.data, required this.recebidoCentavos, required this.previstoCentavos});

  final DateTime data;
  final int recebidoCentavos;
  final int previstoCentavos;

  factory FaturamentoDia.fromJson(Map<String, dynamic> json) => FaturamentoDia(
        data: _data(json['data']),
        recebidoCentavos: centavosDe(json['recebido']),
        previstoCentavos: centavosDe(json['previsto']),
      );
}

class FaturamentoServico {
  const FaturamentoServico({required this.servico, required this.quantidade, required this.recebidoCentavos});

  final String servico;

  /// Quantidade de atendimentos REALIZADO do serviço no período.
  final int quantidade;
  final int recebidoCentavos;

  factory FaturamentoServico.fromJson(Map<String, dynamic> json) => FaturamentoServico(
        servico: (json['servico'] as String?) ?? '',
        quantidade: _inteiro(json['quantidade']),
        recebidoCentavos: centavosDe(json['recebido']),
      );
}

/// Converte o valor da API para centavos sem passar por `double` quando vem em texto:
/// `"1234.50"` → 123450, `"35"` → 3500, `"7.5"` → 750. Número (`35.5`) também é aceito
/// (arredondado para o centavo). Valor ausente ou inválido → 0.
int centavosDe(Object? valor) {
  if (valor == null) return 0;
  if (valor is int) return valor * 100;
  if (valor is num) return (valor * 100).round();
  final texto = valor.toString().trim();
  final m = RegExp(r'^(-?)(\d+)(?:[.,](\d{1,2}))?$').firstMatch(texto);
  if (m == null) return 0;
  final reais = int.parse(m.group(2)!);
  final casas = (m.group(3) ?? '').padRight(2, '0');
  final centavos = reais * 100 + int.parse(casas);
  return m.group(1) == '-' ? -centavos : centavos;
}

int _inteiro(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

DateTime _data(Object? v) {
  final d = DateTime.tryParse('${v ?? ''}');
  return d == null ? DateTime(1970) : DateTime(d.year, d.month, d.day);
}
