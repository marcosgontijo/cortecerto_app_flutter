import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router/rotas.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_tokens.dart';

/// Painel Admin: saudação, cards "Agenda" e "Faturamento" (FASE 5) e sair. Os cards
/// "Clientes" e "Serviços" do web ficam para uma fase futura.
class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    final nome = context.watch<SessionController>().usuario?.nome ?? '';
    final theme = Theme.of(context);
    final t = AppTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Painel Admin')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(t.md),
          children: [
            Text(
              nome.isEmpty ? 'Olá, administrador!' : 'Olá, $nome!',
              key: const Key('admin-nome'),
              style: theme.textTheme.headlineSmall,
            ),
            SizedBox(height: t.xs),
            Text(
              'O que você quer gerenciar hoje?',
              style: theme.textTheme.bodyMedium?.copyWith(color: t.onSurfaceMuted),
            ),
            SizedBox(height: t.lg),
            _CardPainel(
              key: const Key('card-agenda'),
              icone: Icons.calendar_month,
              titulo: 'Agenda',
              descricao: 'Gerencie seus horários e agendamentos.',
              onTap: () => context.pushNamed(Rotas.nomeAdminAgenda),
            ),
            SizedBox(height: t.md - 4),
            _CardPainel(
              key: const Key('card-faturamento'),
              icone: Icons.payments_outlined,
              titulo: 'Faturamento',
              descricao: 'Veja quanto a barbearia recebeu por dia, semana e mês.',
              onTap: () => context.pushNamed(Rotas.nomeAdminFaturamento),
            ),
            SizedBox(height: t.xl),
            OutlinedButton.icon(
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

/// Card do Painel (ícone grande + título + descrição + seta), altura mínima 96.
class _CardPainel extends StatelessWidget {
  const _CardPainel({
    super.key,
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.onTap,
  });

  final IconData icone;
  final String titulo;
  final String descricao;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = AppTokens.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 96),
          child: Padding(
            padding: EdgeInsets.all(t.md),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(t.md - 4),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(t.raioCampo),
                  ),
                  child: Icon(icone, size: 32, color: cs.primary),
                ),
                SizedBox(width: t.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: theme.textTheme.titleMedium),
                      SizedBox(height: t.xs),
                      Text(
                        descricao,
                        style: theme.textTheme.bodyMedium?.copyWith(color: t.onSurfaceMuted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: t.onSurfaceMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
