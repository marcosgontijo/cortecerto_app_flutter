/// Serviço da barbearia (`GET /servicos`). `precoServico` é texto no backend (ex.: "35.00").
class Servico {
  const Servico({
    required this.id,
    required this.tipoServico,
    this.descricao,
    this.precoServico,
  });

  final int id;
  final String tipoServico;
  final String? descricao;
  final String? precoServico;

  factory Servico.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    return Servico(
      id: id is num ? id.toInt() : int.tryParse('$id') ?? 0,
      tipoServico: (json['tipoServico'] ?? '').toString(),
      descricao: json['descricao']?.toString(),
      precoServico: json['precoServico']?.toString(),
    );
  }

  /// Formato enviado no `POST /agendamento` (o backend resolve pelo `tipoServico`).
  Map<String, dynamic> toAgendamentoJson() => {
        'tipoServico': tipoServico,
        'descricao': descricao,
        'precoServico': precoServico,
      };

  @override
  bool operator ==(Object other) =>
      other is Servico && other.id == id && other.tipoServico == tipoServico;

  @override
  int get hashCode => Object.hash(id, tipoServico);
}
