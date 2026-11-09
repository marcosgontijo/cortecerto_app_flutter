import '../../agendamento/domain/status_agendamento.dart';

/// Item de `GET /agendamento/meus`.
class MeuAgendamento {
  const MeuAgendamento({
    required this.id,
    required this.data,
    required this.horario,
    required this.status,
    required this.servico,
  });

  final int id;
  final DateTime data;

  /// `HH:mm`.
  final String horario;
  final StatusAgendamento status;
  final String servico;

  DateTime get dataHoraInicio => dataHora(data, horario);

  factory MeuAgendamento.fromJson(Map<String, dynamic> json) => MeuAgendamento(
        id: intDaApi(json['id']),
        data: dataDaApi(json['data']),
        horario: '${json['horario'] ?? ''}',
        status: StatusAgendamento.deApi(json['status']),
        servico: '${json['servico'] ?? ''}',
      );
}
