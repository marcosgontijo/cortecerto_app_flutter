import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/session/session_controller.dart';

/// Painel Admin provisório (o painel completo é da FASE 3).
class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    final nome = context.watch<SessionController>().usuario?.nome ?? '';
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Painel Admin')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.admin_panel_settings, size: 72, color: theme.colorScheme.secondary),
              const SizedBox(height: 16),
              Text(
                nome.isEmpty ? 'Olá, administrador!' : 'Olá, $nome!',
                key: const Key('admin-nome'),
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'As funções de administração (agenda, clientes e serviços) '
                'chegam na próxima versão do app.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                key: const Key('botao-sair-admin'),
                onPressed: () => context.read<SessionController>().sair(),
                icon: const Icon(Icons.logout),
                label: const Text('Sair'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
