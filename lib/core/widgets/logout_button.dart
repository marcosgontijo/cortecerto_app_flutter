import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../session/session_controller.dart';

/// Botão "Sair" das telas logadas. O redirect do router leva ao Login.
class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('botao-sair'),
      tooltip: 'Sair',
      icon: const Icon(Icons.logout),
      onPressed: () => context.read<SessionController>().sair(),
    );
  }
}
