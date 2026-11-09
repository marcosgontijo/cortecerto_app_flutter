import 'dart:async';

import 'package:flutter/material.dart';

/// Botão primário (`FilledButton`) com estado de envio: mostra um indicador pequeno e
/// fica desabilitado enquanto [enviando] for `true` ou enquanto o `Future` devolvido
/// por [onPressed] não terminar. Dois toques seguidos geram uma única chamada.
class BotaoPrimario extends StatefulWidget {
  const BotaoPrimario({
    super.key,
    required this.rotulo,
    required this.onPressed,
    this.enviando = false,
    this.icone,
  });

  final String rotulo;

  /// `null` desabilita o botão.
  final FutureOr<void> Function()? onPressed;
  final bool enviando;
  final IconData? icone;

  @override
  State<BotaoPrimario> createState() => _BotaoPrimarioState();
}

class _BotaoPrimarioState extends State<BotaoPrimario> {
  bool _ocupado = false;

  bool get _enviando => widget.enviando || _ocupado;

  Future<void> _tocar() async {
    final acao = widget.onPressed;
    if (acao == null || _enviando) return;
    _ocupado = true; // trava já no primeiro toque, antes do próximo frame
    try {
      final r = acao();
      if (r is Future) {
        if (mounted) setState(() {});
        await r;
      }
    } finally {
      _ocupado = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final habilitado = widget.onPressed != null && !_enviando;
    final Widget filho;
    if (_enviando) {
      filho = Semantics(
        label: 'Enviando',
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.onSurface),
        ),
      );
    } else if (widget.icone != null) {
      filho = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icone, size: 20),
          const SizedBox(width: 8),
          Flexible(child: Text(widget.rotulo, textAlign: TextAlign.center)),
        ],
      );
    } else {
      filho = Text(widget.rotulo, textAlign: TextAlign.center);
    }
    return FilledButton(
      onPressed: habilitado ? _tocar : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: filho,
      ),
    );
  }
}
