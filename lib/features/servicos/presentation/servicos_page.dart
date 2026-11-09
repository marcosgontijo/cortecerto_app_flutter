import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters/formatters.dart';
import '../../../core/router/rotas.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/widgets/logout_button.dart';
import '../domain/servico.dart';
import 'servicos_controller.dart';

class ServicosPage extends StatefulWidget {
  const ServicosPage({super.key});

  @override
  State<ServicosPage> createState() => _ServicosPageState();
}

class _ServicosPageState extends State<ServicosPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ServicosController>().carregarServicos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ServicosController>();
    final nome = context.watch<SessionController>().usuario?.nome ?? '';
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Serviços'),
        actions: [
          IconButton(
            key: const Key('botao-meus-agendamentos-appbar'),
            tooltip: 'Meus agendamentos',
            icon: const Icon(Icons.event_note),
            onPressed: () => context.pushNamed(Rotas.nomeMeusAgendamentos),
          ),
          IconButton(
            key: const Key('botao-produtos-appbar'),
            tooltip: 'Produtos',
            icon: const Icon(Icons.shopping_bag_outlined),
            onPressed: () => context.pushNamed(Rotas.nomeProdutos),
          ),
          const LogoutButton(),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              nome.isEmpty ? 'Olá!' : 'Olá, $nome!',
              key: const Key('saudacao'),
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Selecione o serviço de hoje',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Expanded(child: _conteudo(context, controller)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('botao-meus-agendamentos'),
              onPressed: () => context.pushNamed(Rotas.nomeMeusAgendamentos),
              icon: const Icon(Icons.event_note),
              label: const Text('Meus agendamentos'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('botao-produtos'),
              onPressed: () => context.pushNamed(Rotas.nomeProdutos),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('Ver produtos'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conteudo(BuildContext context, ServicosController controller) {
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.erro != null) {
      return _Estado(
        key: const Key('servicos-erro'),
        icone: Icons.error_outline,
        texto: controller.erro!,
        acao: 'Tentar novamente',
        onAcao: controller.carregarServicos,
      );
    }
    if (controller.isVazio) {
      return _Estado(
        key: const Key('servicos-vazio'),
        icone: Icons.inbox_outlined,
        texto: 'Nenhum serviço disponível no momento.',
        acao: 'Tentar novamente',
        onAcao: controller.carregarServicos,
      );
    }
    return RefreshIndicator(
      onRefresh: controller.carregarServicos,
      child: ListView.separated(
        itemCount: controller.servicos.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _ServicoCard(servico: controller.servicos[i]),
      ),
    );
  }
}

class _ServicoCard extends StatelessWidget {
  const _ServicoCard({required this.servico});

  final Servico servico;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      key: Key('servico-${servico.id}'),
      color: cs.surface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(iconeDoServico(servico.tipoServico), color: cs.secondary, size: 32),
        title: Text(
          servico.tipoServico,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: (servico.descricao ?? '').isEmpty ? null : Text(servico.descricao!),
        trailing: Text(
          Formatters.precoTexto(servico.precoServico),
          style: TextStyle(color: cs.secondary, fontWeight: FontWeight.bold),
        ),
        onTap: () => context.pushNamed(Rotas.nomeAgendamento, extra: servico),
      ),
    );
  }
}

/// Ícones por tipo, como no web.
IconData iconeDoServico(String tipo) {
  switch (tipo) {
    case 'Corte Simples':
      return Icons.content_cut;
    case 'Corte + Barba':
      return Icons.face;
    case 'Barba':
      return Icons.person;
    case 'Sobrancelha':
      return Icons.remove_red_eye;
    case 'Corte Completo':
      return Icons.sentiment_satisfied;
    default:
      return Icons.content_cut;
  }
}

class _Estado extends StatelessWidget {
  const _Estado({
    super.key,
    required this.icone,
    required this.texto,
    required this.acao,
    required this.onAcao,
  });

  final IconData icone;
  final String texto;
  final String acao;
  final VoidCallback onAcao;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 48),
          const SizedBox(height: 12),
          Text(texto, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onAcao,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(acao),
            ),
          ),
        ],
      ),
    );
  }
}
