import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters/formatters.dart';
import '../../../core/router/rotas.dart';
import '../../../core/widgets/logout_button.dart';
import '../../agendamento/domain/status_agendamento.dart';
import '../domain/meu_agendamento.dart';
import 'meus_agendamentos_controller.dart';

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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar agendamento'),
        content: Text(
            'Cancelar ${a.servico} em ${Formatters.data(a.data)} às ${a.horario}?'),
        actions: [
          TextButton(
            key: const Key('dialogo-nao'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Voltar'),
          ),
          TextButton(
            key: const Key('dialogo-sim'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancelar agendamento'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final erro = await c.cancelar(a);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      key: Key(erro == null ? 'snack-sucesso' : 'snack-erro'),
      content: Text(erro ?? 'Agendamento cancelado.'),
      backgroundColor: erro == null ? null : Theme.of(context).colorScheme.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<MeusAgendamentosController>();
    // Se a pilha só tem esta tela (veio do Confirmado com go), o Voltar leva aos serviços.
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
            title: const Text('Meus agendamentos'),
            actions: const [LogoutButton()],
            bottom: TabBar(
              tabs: [
                Tab(key: const Key('aba-proximos'), text: 'Próximos (${c.proximos.length})'),
                Tab(key: const Key('aba-historico'), text: 'Histórico (${c.historico.length})'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _Lista(
                key: const Key('lista-proximos'),
                controller: c,
                itens: c.proximos,
                vazio: 'Você não tem agendamentos futuros.',
                onCancelar: _cancelar,
              ),
              _Lista(
                key: const Key('lista-historico'),
                controller: c,
                itens: c.historico,
                vazio: 'Nenhum agendamento no histórico.',
                onCancelar: _cancelar,
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
    required this.vazio,
    required this.onCancelar,
  });

  final MeusAgendamentosController controller;
  final List<MeuAgendamento> itens;
  final String vazio;
  final void Function(MeuAgendamento) onCancelar;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final List<Widget> filhos;
    if (c.isLoading && !c.carregou) {
      filhos = const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator(key: Key('meus-carregando'))),
        ),
      ];
    } else if (c.erro != null) {
      filhos = [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            key: const Key('meus-erro'),
            children: [
              Text(c.erro!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: c.carregar,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Tentar novamente'),
                ),
              ),
            ],
          ),
        ),
      ];
    } else if (itens.isEmpty) {
      filhos = [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Text(vazio, key: const Key('meus-vazio'), textAlign: TextAlign.center),
        ),
      ];
    } else {
      filhos = [
        for (final a in itens)
          Card(
            key: Key('meu-agendamento-${a.id}'),
            child: ListTile(
              title: Text(a.servico, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Text('${Formatters.data(a.data)} às ${a.horario}'),
                    const SizedBox(width: 8),
                    StatusChip(status: a.status),
                  ],
                ),
              ),
              trailing: c.podeCancelar(a)
                  ? TextButton(
                      key: Key('botao-cancelar-${a.id}'),
                      onPressed: c.cancelando == null ? () => onCancelar(a) : null,
                      child: const Text('Cancelar'),
                    )
                  : null,
            ),
          ),
      ];
    }
    return RefreshIndicator(
      onRefresh: c.carregar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: filhos,
      ),
    );
  }
}
