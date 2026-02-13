class Disponibilidade {

  final DateTime data;
  final List<String> horarios;

  Disponibilidade({
    required this.data,
    required this.horarios,
  });

  factory Disponibilidade.fromJson(Map<String, dynamic> json) {

    return Disponibilidade(
      data: DateTime.parse(json['data']),
      horarios: List<String>.from(
        json['horarios'].map((h) {
          return h.toString().substring(0, 5);
        }),
      ),
    );
  }
}
