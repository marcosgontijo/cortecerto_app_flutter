import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Bloco de aviso informativo (ex.: "Sessão expirada", "Cadastro realizado").
class BlocoAviso extends StatelessWidget {
  const BlocoAviso({super.key, required this.texto, this.icone = Icons.info_outline});

  final String texto;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppTokens.of(context);
    return _Bloco(
      fundo: t.surfaceHigh,
      borda: cs.primary,
      corIcone: cs.primary,
      corTexto: cs.onSurface,
      icone: icone,
      texto: texto,
    );
  }
}

/// Bloco de erro perto da ação que falhou (ex.: erro do servidor no Login).
class BlocoErro extends StatelessWidget {
  const BlocoErro({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Bloco(
      fundo: cs.errorContainer,
      borda: cs.error,
      corIcone: cs.error,
      corTexto: cs.onErrorContainer,
      icone: Icons.error_outline,
      texto: texto,
    );
  }
}

class _Bloco extends StatelessWidget {
  const _Bloco({
    required this.fundo,
    required this.borda,
    required this.corIcone,
    required this.corTexto,
    required this.icone,
    required this.texto,
  });

  final Color fundo;
  final Color borda;
  final Color corIcone;
  final Color corTexto;
  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: EdgeInsets.all(t.md - 4),
        decoration: BoxDecoration(
          color: fundo,
          border: Border.all(color: borda),
          borderRadius: BorderRadius.circular(t.raioCampo),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, color: corIcone, size: 20),
            SizedBox(width: t.sm),
            Expanded(
              child: Text(
                texto,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: corTexto),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
