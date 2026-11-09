import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/rotas.dart';
import '../../../core/session/session_controller.dart';

/// Painel Admin: saudação, card "Agenda" e sair. Os cards "Clientes" e "Serviços"
/// do web ficam para uma fase futura.
class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    final nome = context.watch<SessionController>().usuario?.nome ?? '';
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Painel Admin')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(Icons.admin_panel_settings, size: 72, color: cs.secondary),
            const SizedBox(height: 16),
            Text(
              nome.isEmpty ? 'Olá, administrador!' : 'Olá, $nome!',
              key: const Key('admin-nome'),
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text('Painel do Administrador', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Card(
              key: const Key('card-agenda'),
              color: cs.surface,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                leading: Icon(Icons.calendar_month, size: 40, color: cs.secondary),
                title: const Text('Agenda', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Gerencie seus horários e agendamentos.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed(Rotas.nomeAdminAgenda),
              ),
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
    );
  }
}
