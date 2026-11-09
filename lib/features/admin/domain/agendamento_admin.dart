import '../../agendamento/domain/status_agendamento.dart';

/// Agendamento como o admin vê (`/agendamento/admin`): inclui o telefone do cliente.
class AgendamentoAdmin {
  const AgendamentoAdmin({
    required this.id,
    required this.data,
    required this.horario,
    required this.status,
    required this.servicoId,
    required this.servico,
    required this.clienteId,
    required this.nomeCliente,
    this.telefoneCliente,
  });

  final int id;
  final DateTime data;

  /// `HH:mm`.
  final String horario;
  final StatusAgendamento status;
  final int servicoId;
  final String servico;
  final int clienteId;
  final String nomeCliente;

  /// Pode ser `null` (ex.: admin criado pelo sistema, cadastros antigos).
  final String? telefoneCliente;

  factory AgendamentoAdmin.fromJson(Map<String, dynamic> json) => AgendamentoAdmin(
        id: intDaApi(json['id']),
        data: dataDaApi(json['data']),
        horario: '${json['horario'] ?? ''}',
        status: StatusAgendamento.deApi(json['status']),
        servicoId: intDaApi(json['servicoId']),
        servico: '${json['servico'] ?? ''}',
        clienteId: intDaApi(json['clienteId']),
        nomeCliente: '${json['nomeCliente'] ?? ''}',
        telefoneCliente: json['telefoneCliente']?.toString(),
      );
}

/// Cliente devolvido pela busca do admin (`GET /clientes?busca=`): CPF já vem mascarado.
class ClienteResumo {
  const ClienteResumo({required this.id, required this.nome, this.cpf, this.telefone});

  final int id;
  final String nome;
  final String? cpf;
  final String? telefone;

  factory ClienteResumo.fromJson(Map<String, dynamic> json) => ClienteResumo(
        id: intDaApi(json['id']),
        nome: '${json['nome'] ?? ''}',
        cpf: json['cpf']?.toString(),
        telefone: json['telefone']?.toString(),
      );

  @override
  bool operator ==(Object other) => other is ClienteResumo && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
