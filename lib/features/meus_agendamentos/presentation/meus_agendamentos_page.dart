import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters/formatters.dart';
import '../../../core/router/rotas.dart';
import '../../../core/widgets/logout_button.dart';
import '../../agendamento/domain/status_agendamento.dart';
import '../domain/meu_agendamento.dart';
import 'meus_agendamentos_controller.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/cliente_navigation_bar.dart';
import '../../../core/widgets/dialogo_confirmacao.dart';
import '../../../core/widgets/estados.dart';
import '../../../core/widgets/feedback.dart';

/// Meus Agendamentos (`/meus-agendamentos`): Próximos e Histórico, sempre do servidor
/// (ao abrir, ao puxar para atualizar e quando o app volta ao primeiro plano).
class MeusAgendamentosPage extends StatefulWidget {
  const MeusAgendamentosPage({super.key});

  @override
  State<MeusAgendamentosPage> createState() => _MeusAgendamentosPageState();
}

class _MeusAgendamentosPageState extends State<MeusAgendamentosPage> {
  late final AppLifecycleListener _ciclo;

  @override
  void initState() {
    super.initState();
    _ciclo = AppLifecycleListener(onResume: _recarregar);
    WidgetsBinding.instance.addPostFrameCallback((_) => _recarregar());
  }

  void _recarregar() {
    if (mounted) context.read<MeusAgendamentosController>().carregar();
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  void _voltar() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(Rotas.nomeServicos);
    }
  }

  Future<void> _cancelar(MeuAgendamento a) async {
    final c = context.read<MeusAgendamentosController>();
    final ok = await confirmarAcao(
      context,
      titulo: 'Cancelar agendamento',
      mensagem: 'Cancelar ${a.servico} em ${Formatters.data(a.data)} às ${a.horario}? '
          'O horário ficará livre para outra pessoa.',
      rotuloConfirmar: 'Cancelar agendamento',
      icone: Icons.event_busy,
    );
    if (!ok || !mounted) return;
    final erro = await c.cancelar(a);
    if (!mounted) return;
    mostrarFeedback(context, erro ?? 'Agendamento cancelado.', erro: erro != null);
  }

  void _agendar() => context.goNamed(Rotas.nomeServicos);

  @override
  Widget build(BuildContext context) {
    final c = context.watch<MeusAgendamentosController>();
    // Se a pilha só tem esta tela (veio do Confirmado ou da barra com go), o Voltar
    // leva aos serviços.
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.goNamed(Rotas.nomeServicos);
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              key: const Key('botao-voltar'),
              tooltip: 'Voltar',
              icon: const Icon(Icons.arrow_back),
              onPressed: _voltar,
            ),
            // O título não repete o rótulo "Meus agendamentos" da barra inferior.
            title: const Text('Seus horários'),
            actions: const [LogoutButton()],
            bottom: TabBar(
              tabs: [
                Tab(
                  key: const Key('aba-proximos'),
                  height: 48,
                  text: 'Próximos (${c.proximos.length})',
                ),
                Tab(
                  key: const Key('aba-historico'),
                  height: 48,
                  text: 'Histórico (${c.historico.length})',
                ),
              ],
            ),
          ),
          bottomNavigationBar: const ClienteNavigationBar(atual: DestinoCliente.meusAgendamentos),
          body: TabBarView(
            children: [
              _Lista(
                key: const Key('lista-proximos'),
                controller: c,
                itens: c.proximos,
                vazioTitulo: 'Nenhum agendamento futuro',
                vazioTexto: 'Você não tem agendamentos futuros.',
                onCancelar: _cancelar,
                onAgendar: _agendar,
              ),
              _Lista(
                key: const Key('lista-historico'),
                controller: c,
                itens: c.historico,
                vazioTitulo: 'Histórico vazio',
                vazioTexto: 'Nenhum agendamento no histórico.',
                onCancelar: _cancelar,
                onAgendar: _agendar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Lista extends StatelessWidget {
  const _Lista({
    super.key,
    required this.controller,
    required this.itens,
    required this.vazioTitulo,
    required this.vazioTexto,
    required this.onCancelar,
    required this.onAgendar,
  });

  final MeusAgendamentosController controller;
  final List<MeuAgendamento> itens;
  final String vazioTitulo;
  final String vazioTexto;
  final void Function(MeuAgendamento) onCancelar;
  final VoidCallback onAgendar;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final t = AppTokens.of(context);
    final List<Widget> filhos;
    if (c.isLoading && !c.carregou) {
      filhos = const [
        EstadoCarregando(
          mensagem: 'Carregando agendamentos',
          chaveIndicador: Key('meus-carregando'),
        ),
      ];
    } else if (c.erro != null) {
      filhos = [
        EstadoErro(key: const Key('meus-erro'), mensagem: c.erro!, onTentarNovamente: c.carregar),
      ];
    } else if (itens.isEmpty) {
      filhos = [
        EstadoVazio(
          key: const Key('meus-vazio'),
          icone: Icons.event_available_outlined,
          titulo: vazioTitulo,
          texto: vazioTexto,
          rotuloAcao: 'Agendar um horário',
          iconeAcao: Icons.add,
          onAcao: onAgendar,
        ),
      ];
    } else {
      filhos = [
        for (final a in itens) ...[
          _CardAgendamento(
            agendamento: a,
            podeCancelar: c.podeCancelar(a),
            cancelando: c.cancelando != null,
            onCancelar: () => onCancelar(a),
          ),
          SizedBox(height: t.md - 4),
        ],
      ];
    }
    return RefreshIndicator(
      onRefresh: c.carregar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(t.md),
        children: filhos,
      ),
    );
  }
}

class _CardAgendamento extends StatelessWidget {
  const _CardAgendamento({
    required this.agendamento,
    required this.podeCancelar,
    required this.cancelando,
    required this.onCancelar,
  });

  final MeuAgendamento agendamento;
  final bool podeCancelar;
  final bool cancelando;
  final VoidCallback onCancelar;

  @override
  Widget build(BuildContext context) {
    final a = agendamento;
    final cs = Theme.of(context).colorScheme;
    final t = AppTokens.of(context);
    final tema = Theme.of(context).textTheme;
    return Card(
      key: Key('meu-agendamento-${a.id}'),
      child: Padding(
        padding: EdgeInsets.all(t.md),
        // stretch: o Wrap abaixo recebe a largura toda do card, para o
        // spaceBetween levar o "Cancelar" para a direita (MASTER.md).
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.event_outlined, color: cs.primary, size: 24),
                SizedBox(width: t.sm + 4),
                Expanded(
                  child: Text(
                    '${Formatters.data(a.data)} às ${a.horario}',
                    style: tema.titleMedium,
                  ),
                ),
              ],
            ),
            SizedBox(height: t.xs),
            Padding(
              padding: EdgeInsets.only(left: 24 + t.sm + 4),
              child: Text(a.servico, style: tema.bodyLarge?.copyWith(color: t.onSurfaceMuted)),
            ),
            SizedBox(height: t.sm),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: t.sm,
              runSpacing: t.sm,
              children: [
                StatusChip(status: a.status),
                if (podeCancelar)
                  TextButton(
                    key: Key('botao-cancelar-${a.id}'),
                    style: TextButton.styleFrom(foregroundColor: cs.error),
                    onPressed: cancelando ? null : onCancelar,
                    child: const Text('Cancelar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
