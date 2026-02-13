class DiaHorarioDisponivel {

  final DateTime data;
  final List<String> horarios;

  DiaHorarioDisponivel({
    required this.data,
    required this.horarios,
  });

  factory DiaHorarioDisponivel.fromJson(Map<String, dynamic> json) {

    return DiaHorarioDisponivel(
      data: DateTime.parse(json['data']),
      horarios: (json['horarios'] as List)
          .map((h) => h.toString().substring(0, 5))
          .toList(),
    );
  }
}
