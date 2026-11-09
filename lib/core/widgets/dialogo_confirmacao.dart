import 'package:flutter/material.dart';

/// Diálogo de confirmação (ações destrutivas). Devolve `true` só se o usuário
/// confirmar; "Voltar", tocar fora ou o Voltar do Android devolvem `false`.
/// O botão de confirmar fica na cor `error` quando [destrutivo].
Future<bool> confirmarAcao(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  required String rotuloConfirmar,
  String rotuloCancelar = 'Voltar',
  bool destrutivo = true,
  IconData? icone,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return AlertDialog(
        icon: icone == null ? null : Icon(icone, color: destrutivo ? cs.error : cs.primary),
        title: Text(titulo),
        content: Text(mensagem),
        actions: [
          TextButton(
            key: const Key('dialogo-nao'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(rotuloCancelar),
          ),
          TextButton(
            key: const Key('dialogo-sim'),
            style: destrutivo ? TextButton.styleFrom(foregroundColor: cs.error) : null,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(rotuloConfirmar),
          ),
        ],
      );
    },
  );
  return ok == true;
}
