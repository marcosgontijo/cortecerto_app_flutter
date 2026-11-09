import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters/formatters.dart';
import '../../../core/router/rotas.dart';
import '../../agendamento/domain/status_agendamento.dart';
import '../domain/agendamento_admin.dart';
import 'agenda_admin_controller.dart';
import 'agendamento_form_controller.dart';

/// Agenda Admin (`/admin/agenda`): escolha do dia, grade 08:00–19:30, contadores,
/// filtro por status, busca por nome, criar, detalhes e ações.
class AgendaAdminPage extends StatefulWidget {
  const AgendaAdminPage({super.key});

  @override
  State<AgendaAdminPage> createState() => _AgendaAdminPageState();
}

class _AgendaAdminPageState extends State<AgendaAdminPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AgendaAdminController>().carregar();
    });
  }

  String _titulo(AgendaAdminController c) {
    switch (c.periodo) {
      case PeriodoAgenda.hoje:
        return 'Agenda - Hoje';
      case PeriodoAgenda.amanha:
        return 'Agenda - Amanhã';
      case PeriodoAgenda.data:
        return 'Agenda - ${Formatters.data(c.dia)}';
    }
  }

  void _avisar(String mensagem, {bool erro = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      key: Key(erro ? 'snack-erro' : 'snack-sucesso'),
      content: Text(mensagem),
      backgroundColor: erro ? Theme.of(context).colorScheme.error : null,
    ));
  }

  Future<void> _escolherData(AgendaAdminController c) async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: c.diaInicialCalendario,
      firstDate: c.primeiroDiaCalendario,
      lastDate: c.ultimoDiaCalendario,
      helpText: 'Escolha a data',
    );
    if (escolhida != null && mounted) await c.selecionarData(escolhida);
  }

  /// Abre o formulário (criar ou editar) e recarrega a agenda ao voltar.
  Future<void> _abrirFormulario(AgendamentoFormArgs args) async {
    final c = context.read<AgendaAdminController>();
    final salvou = await context.pushNamed<bool>(Rotas.nomeAdminAgendamentoForm, extra: args);
    if (!mounted) return;
    if (salvou == true) {
      _avisar(args.editando ? 'Agendamento atualizado.' : 'Agendamento criado.');
    }
    await c.carregar();
  }

  Future<bool> _confirmarDialogo(String titulo, String texto, String acao) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(
            key: const Key('dialogo-nao'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Voltar'),
          ),
          TextButton(
            key: const Key('dialogo-sim'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(acao),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _executar(Future<ResultadoAcao> Function() acao) async {
    final r = await acao();
    _avisar(r.mensagem, erro: !r.sucesso);
  }

  Future<void> _abrirDetalhes(AgendamentoAdmin a) async {
    final c = context.read<AgendaAdminController>();
    final escolha = await showModalBottomSheet<_AcaoDetalhe>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _Detalhes(agendamento: a),
    );
    if (escolha == null || !mounted) return;
    switch (escolha) {
      case _AcaoDetalhe.editar:
        await _abrirFormulario(AgendamentoFormArgs.editar(a));
      case _AcaoDetalhe.confirmar:
        await _executar(() => c.confirmar(a));
      case _AcaoDetalhe.realizar:
        await _executar(() => c.marcarRealizado(a));
      case _AcaoDetalhe.cancelar:
        if (await _confirmarDialogo('Cancelar agendamento',
            'Cancelar o agendamento de ${a.nomeCliente} às ${a.horario}? O horário ficará livre.',
            'Cancelar agendamento')) {
          await _executar(() => c.cancelar(a));
        }
      case _AcaoDetalhe.excluir:
        if (await _confirmarDialogo('Excluir agendamento',
            'Excluir definitivamente o agendamento de ${a.nomeCliente} às ${a.horario}?',
            'Excluir')) {
          await _executar(() => c.excluir(a));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AgendaAdminController>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulo(c), key: const Key('agenda-titulo')),
        actions: [
          IconButton(
            key: const Key('botao-novo-agendamento'),
            tooltip: 'Novo agendamento',
            icon: const Icon(Icons.add),
            onPressed: () => _abrirFormulario(AgendamentoFormArgs.criar(data: c.dia)),
          ),
        ],
      ),
      body: RefreshIndicator(
        key: const Key('agenda-refresh'),
        onRefresh: c.carregar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          children: [
            _Periodo(controller: c, onData: () => _escolherData(c)),
            const SizedBox(height: 8),
            _FiltroStatus(controller: c),
            const SizedBox(height: 8),
            TextField(
              key: const Key('campo-busca-agenda'),
              decoration: const InputDecoration(
                hintText: 'Pesquisar cliente...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: c.buscar,
            ),
            const SizedBox(height: 12),
            _Resumo(controller: c),
            const SizedBox(height: 12),
            ..._conteudo(c),
          ],
        ),
      ),
    );
  }

  List<Widget> _conteudo(AgendaAdminController c) {
    if (c.isLoading && !c.carregou) {
      return const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(key: Key('agenda-carregando'))),
        ),
      ];
    }
    if (c.erro != null) {
      return [
        Column(
          key: const Key('agenda-erro'),
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
      ];
    }
    if (c.temFiltro) {
      final lista = c.filtrados;
      if (lista.isEmpty) {
        return [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Nenhum agendamento encontrado para ${Formatters.data(c.dia)}.',
              key: const Key('agenda-vazia'),
              textAlign: TextAlign.center,
            ),
          ),
        ];
      }
      return [
        for (final a in lista)
          _CardAgendamento(
            key: Key('agendamento-${a.id}'),
            agendamento: a,
            onTap: () => _abrirDetalhes(a),
          ),
      ];
    }
    return [
      for (final s in c.slots)
        s.disponivel
            ? _SlotDisponivel(
                key: Key('agenda-horario-${s.horario}'),
                slot: s,
                // Horário que já passou não recebe agendamento novo (o backend recusaria).
                onTap: c.horarioPassou(s.horario)
                    ? null
                    : () => _abrirFormulario(
                        AgendamentoFormArgs.criar(data: c.dia, horario: s.horario)),
              )
            : _CardAgendamento(
                key: Key('agenda-horario-${s.horario}'),
                agendamento: s.agendamento!,
                onTap: () => _abrirDetalhes(s.agendamento!),
              ),
    ];
  }
}

class _Periodo extends StatelessWidget {
  const _Periodo({required this.controller, required this.onData});

  final AgendaAdminController controller;
  final VoidCallback onData;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          key: const Key('periodo-hoje'),
          label: const Text('Hoje'),
          selected: c.periodo == PeriodoAgenda.hoje,
          onSelected: (_) => c.selecionarHoje(),
        ),
        ChoiceChip(
          key: const Key('periodo-amanha'),
          label: const Text('Amanhã'),
          selected: c.periodo == PeriodoAgenda.amanha,
          onSelected: (_) => c.selecionarAmanha(),
        ),
        ChoiceChip(
          key: const Key('periodo-data'),
          avatar: const Icon(Icons.event, size: 18),
          label: Text(c.periodo == PeriodoAgenda.data ? Formatters.data(c.dia) : 'Data'),
          selected: c.periodo == PeriodoAgenda.data,
          onSelected: (_) => onData(),
        ),
      ],
    );
  }
}

class _FiltroStatus extends StatelessWidget {
  const _FiltroStatus({required this.controller});

  final AgendaAdminController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            key: const Key('filtro-todos'),
            label: const Text('Todos'),
            selected: c.filtroStatus == null,
            onSelected: (_) => c.filtrarStatus(null),
          ),
          for (final s in StatusAgendamento.conhecidos)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                key: Key('filtro-${s.api}'),
                label: Text(s.rotulo),
                selected: c.filtroStatus == s,
                onSelected: (_) => c.filtrarStatus(c.filtroStatus == s ? null : s),
              ),
            ),
        ],
      ),
    );
  }
}

class _Resumo extends StatelessWidget {
  const _Resumo({required this.controller});

  final AgendaAdminController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    Widget item(String chave, String rotulo, int n, Color? cor) => Expanded(
          child: Card(
            key: Key('contador-$chave'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              child: Column(
                children: [
                  Text('$n',
                      key: Key('contador-$chave-valor'),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cor)),
                  FittedBox(child: Text(rotulo, style: const TextStyle(fontSize: 11))),
                ],
              ),
            ),
          ),
        );
    return Row(
      children: [
        item('total', 'Total', c.total, null),
        for (final s in StatusAgendamento.conhecidos) item(s.api, '${s.rotulo}s', c.contar(s), s.cor),
      ],
    );
  }
}

class _SlotDisponivel extends StatelessWidget {
  const _SlotDisponivel({super.key, required this.slot, required this.onTap});

  final SlotAgenda slot;

  /// `null` quando o horário já passou: o slot fica desabilitado, sem o "+".
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final n = slot.cancelados.length;
    final passou = onTap == null;
    return Card(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
      child: ListTile(
        dense: true,
        enabled: !passou,
        leading: Text(slot.horario, style: const TextStyle(fontWeight: FontWeight.bold)),
        title: Text(passou ? 'Horário encerrado' : 'Disponível'),
        subtitle: n == 0 ? null : Text(n == 1 ? '1 cancelado neste horário' : '$n cancelados neste horário'),
        trailing: passou ? null : const Icon(Icons.add_circle_outline, key: Key('slot-adicionar')),
        onTap: onTap,
      ),
    );
  }
}

class _CardAgendamento extends StatelessWidget {
  const _CardAgendamento({super.key, required this.agendamento, required this.onTap});

  final AgendamentoAdmin agendamento;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = agendamento;
    return Card(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: a.status.cor, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Text(a.horario, style: const TextStyle(fontWeight: FontWeight.bold)),
        title: Text(a.nomeCliente),
        subtitle: Text(a.servico),
        trailing: StatusChip(status: a.status),
        onTap: onTap,
      ),
    );
  }
}

enum _AcaoDetalhe { editar, confirmar, realizar, cancelar, excluir }

class _Detalhes extends StatelessWidget {
  const _Detalhes({required this.agendamento});

  final AgendamentoAdmin agendamento;

  @override
  Widget build(BuildContext context) {
    final a = agendamento;
    final tel = (a.telefoneCliente ?? '').trim();
    void escolher(_AcaoDetalhe acao) => Navigator.of(context).pop(acao);
    Widget linha(String rotulo, String valor, String chave) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text.rich(
            key: Key('detalhe-$chave'),
            TextSpan(children: [
              TextSpan(text: '$rotulo: ', style: const TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: valor),
            ]),
          ),
        );
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('detalhes-agendamento'),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Detalhes do agendamento',
                style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            linha('Cliente', a.nomeCliente, 'cliente'),
            linha('Telefone', tel.isEmpty ? 'Não informado' : tel, 'telefone'),
            linha('Serviço', a.servico, 'servico'),
            linha('Data', Formatters.data(a.data), 'data'),
            linha('Horário', a.horario, 'horario'),
            Row(children: [
              const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
              StatusChip(status: a.status),
            ]),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  key: const Key('acao-editar'),
                  onPressed: () => escolher(_AcaoDetalhe.editar),
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar'),
                ),
                if (a.status == StatusAgendamento.pendente)
                  OutlinedButton.icon(
                    key: const Key('acao-confirmar'),
                    onPressed: () => escolher(_AcaoDetalhe.confirmar),
                    icon: const Icon(Icons.check),
                    label: const Text('Confirmar'),
                  ),
                if (a.status == StatusAgendamento.pendente || a.status == StatusAgendamento.confirmado)
                  OutlinedButton.icon(
                    key: const Key('acao-realizar'),
                    onPressed: () => escolher(_AcaoDetalhe.realizar),
                    icon: const Icon(Icons.done_all),
                    label: const Text('Marcar como realizado'),
                  ),
                if (a.status != StatusAgendamento.cancelado)
                  OutlinedButton.icon(
                    key: const Key('acao-cancelar'),
                    onPressed: () => escolher(_AcaoDetalhe.cancelar),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancelar'),
                  ),
                OutlinedButton.icon(
                  key: const Key('acao-excluir'),
                  onPressed: () => escolher(_AcaoDetalhe.excluir),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Excluir'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('acao-fechar'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        ),
      ),
    );
  }
}
