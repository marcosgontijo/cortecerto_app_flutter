import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters/formatters.dart';
import '../../../core/router/rotas.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/cliente_navigation_bar.dart';
import '../../../core/widgets/estados.dart';
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
    final t = AppTokens.of(context);

    return Scaffold(
      // O título não repete o rótulo "Serviços" da barra inferior (que já indica a aba).
      appBar: AppBar(
        title: const Text('Escolha seu serviço'),
        actions: const [LogoutButton()],
      ),
      bottomNavigationBar: const ClienteNavigationBar(atual: DestinoCliente.servicos),
      body: RefreshIndicator(
        onRefresh: controller.carregarServicos,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(t.md),
          children: [
            Text(
              nome.isEmpty ? 'Olá!' : 'Olá, $nome!',
              key: const Key('saudacao'),
              style: theme.textTheme.headlineSmall,
            ),
            SizedBox(height: t.xs),
            Text(
              'Selecione o serviço que deseja agendar.',
              style: theme.textTheme.bodyMedium?.copyWith(color: t.onSurfaceMuted),
            ),
            SizedBox(height: t.md),
            ..._conteudo(context, controller),
          ],
        ),
      ),
    );
  }

  List<Widget> _conteudo(BuildContext context, ServicosController controller) {
    final t = AppTokens.of(context);
    if (controller.isLoading) {
      return const [EstadoCarregando(mensagem: 'Carregando serviços')];
    }
    if (controller.erro != null) {
      return [
        EstadoErro(
          key: const Key('servicos-erro'),
          mensagem: controller.erro!,
          onTentarNovamente: controller.carregarServicos,
        ),
      ];
    }
    if (controller.isVazio) {
      return [
        EstadoVazio(
          key: const Key('servicos-vazio'),
          icone: Icons.content_cut,
          titulo: 'Nenhum serviço disponível',
          texto: 'Nenhum serviço disponível no momento.',
          rotuloAcao: 'Tentar novamente',
          iconeAcao: Icons.refresh,
          onAcao: controller.carregarServicos,
        ),
      ];
    }
    return [
      for (final s in controller.servicos) ...[
        _ServicoCard(servico: s),
        SizedBox(height: t.md - 4),
      ],
    ];
  }
}

class _ServicoCard extends StatelessWidget {
  const _ServicoCard({required this.servico});

  final Servico servico;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppTokens.of(context);
    final tema = Theme.of(context).textTheme;
    void agendar() => context.pushNamed(Rotas.nomeAgendamento, extra: servico);
    final descricao = (servico.descricao ?? '').trim();
    return Card(
      key: Key('servico-${servico.id}'),
      child: InkWell(
        onTap: agendar,
        child: Padding(
          padding: EdgeInsets.all(t.md),
          // stretch: o Wrap abaixo recebe a largura toda do card, para o
          // spaceBetween levar o "Agendar" para a direita (MASTER.md).
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(t.sm + 2),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(t.raioCampo),
                    ),
                    child: Icon(iconeDoServico(servico.tipoServico), color: cs.primary, size: 24),
                  ),
                  SizedBox(width: t.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(servico.tipoServico, style: tema.titleMedium),
                        if (descricao.isNotEmpty) ...[
                          SizedBox(height: t.xs),
                          Text(
                            servico.descricao!,
                            style: tema.bodyMedium?.copyWith(color: t.onSurfaceMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: t.md - 4),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: t.sm,
                runSpacing: t.sm,
                children: [
                  Text(
                    Formatters.precoTexto(servico.precoServico),
                    style: tema.titleMedium?.copyWith(color: cs.primary),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: agendar,
                    style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                    icon: const Icon(Icons.calendar_month_outlined, size: 20),
                    label: const Text('Agendar'),
                  ),
                ],
              ),
            ],
          ),
        ),
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
