/// Resumo mostrado na tela de agendamento confirmado.
class AgendamentoConfirmado {
  const AgendamentoConfirmado({
    required this.servico,
    required this.data,
    required this.horario,
  });

  /// Nome do serviço (`tipoServico`).
  final String servico;
  final DateTime data;

  /// `HH:mm`.
  final String horario;
}
