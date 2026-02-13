class Servico {

  final int id;
  final String tipoServico;
  final String descricao;
  final String precoServico;
  bool selecionado;

  Servico({
    required this.id,
    required this.tipoServico,
    required this.descricao,
    required this.precoServico,
    this.selecionado = false,
  });

  factory Servico.fromJson(Map<String, dynamic> json) {
    return Servico(
      id: json['id'],
      tipoServico: json['tipoServico'],
      descricao: json['descricao'],
      precoServico: json['precoServico'],
    );
  }
}
