import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Carregando: um único indicador centralizado (com rótulo para leitores de tela).
class EstadoCarregando extends StatelessWidget {
  const EstadoCarregando({super.key, this.mensagem = 'Carregando', this.chaveIndicador});

  final String mensagem;

  /// Key opcional do indicador (mantém Keys antigas como `meus-carregando`).
  final Key? chaveIndicador;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(t.lg),
        child: Semantics(
          label: mensagem,
          child: CircularProgressIndicator(key: chaveIndicador),
        ),
      ),
    );
  }
}

/// Vazio: ícone, título, texto e uma ação opcional.
class EstadoVazio extends StatelessWidget {
  const EstadoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    this.texto,
    this.rotuloAcao,
    this.onAcao,
    this.iconeAcao,
  });

  final IconData icone;
  final String titulo;
  final String? texto;
  final String? rotuloAcao;
  final VoidCallback? onAcao;
  final IconData? iconeAcao;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tema = Theme.of(context).textTheme;
    final temAcao = rotuloAcao != null && onAcao != null;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(t.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 48, color: t.onSurfaceMuted),
            SizedBox(height: t.md),
            Text(titulo, style: tema.titleMedium, textAlign: TextAlign.center),
            if (texto != null) ...[
              SizedBox(height: t.sm),
              Text(
                texto!,
                style: tema.bodyMedium?.copyWith(color: t.onSurfaceMuted),
                textAlign: TextAlign.center,
              ),
            ],
            if (temAcao) ...[
              SizedBox(height: t.md),
              OutlinedButton.icon(
                onPressed: onAcao,
                icon: Icon(iconeAcao ?? Icons.arrow_forward),
                label: Text(rotuloAcao!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Erro: ícone, mensagem e "Tentar novamente" (chama o recarregar do controller).
class EstadoErro extends StatelessWidget {
  const EstadoErro({super.key, required this.mensagem, required this.onTentarNovamente});

  final String mensagem;
  final VoidCallback onTentarNovamente;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(t.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.error),
            SizedBox(height: t.md),
            Text(
              mensagem,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: t.md),
            OutlinedButton.icon(
              onPressed: onTentarNovamente,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
