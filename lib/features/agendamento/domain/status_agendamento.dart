import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Status de um agendamento no backend (`PENDENTE`, `CONFIRMADO`, `CANCELADO`, `REALIZADO`).
/// A cor não fica no enum: vem do tema (ver [StatusAgendamentoVisual]).
enum StatusAgendamento {
  pendente('PENDENTE', 'Pendente'),
  confirmado('CONFIRMADO', 'Confirmado'),
  cancelado('CANCELADO', 'Cancelado'),
  realizado('REALIZADO', 'Realizado'),
  // Valor que o app não conhece (ex.: status novo no backend). Não vira PENDENTE em silêncio:
  // aparece como "Desconhecido" e não ganha ações de status (Confirmar/Realizado).
  desconhecido('DESCONHECIDO', 'Desconhecido');

  const StatusAgendamento(this.api, this.rotulo);

  /// Valor usado na API.
  final String api;

  /// Texto para a tela.
  final String rotulo;

  /// Os quatro status reais do backend (filtros, contadores e escolha no formulário).
  static const List<StatusAgendamento> conhecidos = [pendente, confirmado, cancelado, realizado];

  /// Ocupa o horário (o índice único do backend ignora só CANCELADO; por segurança o
  /// desconhecido também conta como ocupado).
  bool get ocupaHorario => this != StatusAgendamento.cancelado;

  /// Converte o valor da API. Valor que não é um dos [conhecidos] vira [desconhecido].
  static StatusAgendamento deApi(Object? valor) {
    final v = '${valor ?? ''}'.trim().toUpperCase();
    return conhecidos.firstWhere(
      (s) => s.api == v,
      orElse: () => StatusAgendamento.desconhecido,
    );
  }
}

/// Parte visual do status (ícone e cor do tema), separada do valor da API.
extension StatusAgendamentoVisual on StatusAgendamento {
  /// Ícone do MASTER.md: o status nunca é indicado só pela cor.
  IconData get icone => switch (this) {
        StatusAgendamento.pendente => Icons.schedule,
        StatusAgendamento.confirmado => Icons.check_circle,
        StatusAgendamento.realizado => Icons.task_alt,
        StatusAgendamento.cancelado => Icons.cancel,
        StatusAgendamento.desconhecido => Icons.help_outline,
      };

  /// Cor do status vinda dos tokens do tema.
  Color cor(AppTokens t) => switch (this) {
        StatusAgendamento.pendente => t.warning,
        StatusAgendamento.confirmado => t.success,
        StatusAgendamento.realizado => t.info,
        StatusAgendamento.cancelado => t.neutral,
        StatusAgendamento.desconhecido => t.neutral,
      };
}

/// Etiqueta do status: ícone + texto na cor do status, sobre `surfaceHigh`.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final StatusAgendamento status;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final cor = status.cor(t);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.sm, vertical: t.xs),
      decoration: BoxDecoration(
        color: t.surfaceHigh,
        border: Border.all(color: cor),
        borderRadius: BorderRadius.circular(t.raioChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icone, size: 16, color: cor),
          SizedBox(width: t.xs),
          Flexible(
            child: Text(
              status.rotulo,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: cor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Converte `AAAA-MM-DD` da API numa data local (meia-noite), sem fuso.
DateTime dataDaApi(Object? valor) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch('${valor ?? ''}');
  if (m == null) return DateTime(1970);
  return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
}

int intDaApi(Object? valor) => valor is num ? valor.toInt() : int.tryParse('$valor') ?? 0;

/// `HH:mm` como data/hora local no dia [data].
DateTime dataHora(DateTime data, String horario) {
  final partes = horario.split(':');
  final h = partes.isNotEmpty ? int.tryParse(partes[0]) ?? 0 : 0;
  final m = partes.length > 1 ? int.tryParse(partes[1]) ?? 0 : 0;
  return DateTime(data.year, data.month, data.day, h, m);
}
