import 'package:flutter/material.dart';

/// Status de um agendamento no backend (`PENDENTE`, `CONFIRMADO`, `CANCELADO`, `REALIZADO`).
enum StatusAgendamento {
  pendente('PENDENTE', 'Pendente', Color(0xFFFFC107), Colors.black),
  confirmado('CONFIRMADO', 'Confirmado', Color(0xFF28A745), Colors.white),
  cancelado('CANCELADO', 'Cancelado', Color(0xFFDC3545), Colors.white),
  // Azul-petróleo para não confundir com o verde de "confirmado".
  realizado('REALIZADO', 'Realizado', Color(0xFF17A2B8), Colors.white),
  // Valor que o app não conhece (ex.: status novo no backend). Não vira PENDENTE em silêncio:
  // aparece como "Desconhecido" e não ganha ações de status (Confirmar/Realizado).
  desconhecido('DESCONHECIDO', 'Desconhecido', Color(0xFF6C757D), Colors.white);

  const StatusAgendamento(this.api, this.rotulo, this.cor, this.corTexto);

  /// Valor usado na API.
  final String api;

  /// Texto para a tela.
  final String rotulo;
  final Color cor;
  final Color corTexto;

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

/// "Etiqueta" colorida com o status.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final StatusAgendamento status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: status.cor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.rotulo,
        style: TextStyle(color: status.corTexto, fontSize: 12, fontWeight: FontWeight.bold),
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
