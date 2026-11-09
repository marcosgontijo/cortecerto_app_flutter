import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Cabeçalho com a marca CorteCerto (ícone + nome) usado no Login e no Cadastro.
class MarcaCabecalho extends StatelessWidget {
  const MarcaCabecalho({super.key, this.subtitulo});

  final String? subtitulo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppTokens.of(context);
    final tema = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(t.md),
          decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
          child: Icon(Icons.content_cut, size: 40, color: cs.primary),
        ),
        SizedBox(height: t.sm),
        Semantics(
          header: true,
          child: Text(
            'CorteCerto',
            style: tema.headlineSmall?.copyWith(color: cs.primary),
            textAlign: TextAlign.center,
          ),
        ),
        if (subtitulo != null) ...[
          SizedBox(height: t.xs),
          Text(
            subtitulo!,
            style: tema.bodyMedium?.copyWith(color: t.onSurfaceMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
