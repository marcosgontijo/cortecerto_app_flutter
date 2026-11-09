import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// SnackBar flutuante de resultado (Keys `snack-sucesso`/`snack-erro`). Esconde o
/// anterior para as mensagens não se acumularem.
void mostrarFeedback(BuildContext context, String mensagem, {bool erro = false}) {
  final cs = Theme.of(context).colorScheme;
  final t = AppTokens.of(context);
  final corTexto = erro ? cs.onError : cs.onSurface;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    key: Key(erro ? 'snack-erro' : 'snack-sucesso'),
    backgroundColor: erro ? cs.error : t.surfaceHigh,
    content: Row(
      children: [
        Icon(erro ? Icons.error_outline : Icons.check_circle,
            color: erro ? cs.onError : t.success, size: 20),
        SizedBox(width: t.sm),
        Expanded(
          child: Text(
            mensagem,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: corTexto),
          ),
        ),
      ],
    ),
  ));
}
