import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters/formatters.dart';
import '../../../core/router/rotas.dart';
import '../../agendamento/domain/status_agendamento.dart';
import '../domain/agendamento_admin.dart';
import 'agenda_admin_controller.dart';
import 'agendamento_form_controller.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/dialogo_confirmacao.dart';
import '../../../core/widgets/estados.dart';
import '../../../core/widgets/feedback.dart';

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
    mostrarFeedback(context, mensagem, erro: erro);
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
        if (await confirmarAcao(
          context,
          titulo: 'Cancelar agendamento',
          mensagem:
              'Cancelar o agendamento de ${a.nomeCliente} às ${a.horario}? O horário ficará livre.',
          rotuloConfirmar: 'Cancelar agendamento',
          icone: Icons.event_busy,
        )) {
          await _executar(() => c.cancelar(a));
        }
      case _AcaoDetalhe.excluir:
        if (!mounted) return;
        if (await confirmarAcao(
          context,
          titulo: 'Excluir agendamento',
          mensagem:
              'Excluir definitivamente o agendamento de ${a.nomeCliente} às ${a.horario}?',
          rotuloConfirmar: 'Excluir',
          icone: Icons.delete_outline,
        )) {
          await _executar(() => c.excluir(a));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AgendaAdminController>();
    final t = AppTokens.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulo(c), key: const Key('agenda-titulo')),
      ),
      // Só ícone + tooltip: o texto "Novo agendamento" fica para o título do formulário.
      floatingActionButton: FloatingActionButton(
        key: const Key('botao-novo-agendamento'),
        tooltip: 'Novo agendamento',
        onPressed: () => _abrirFormulario(AgendamentoFormArgs.criar(data: c.dia)),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        key: const Key('agenda-refresh'),
        onRefresh: c.carregar,
        // A lista principal é o primeiro Scrollable da tela; período, filtros e busca
        // ficam dentro dela. O espaço no fim deixa o último horário acima do FAB.
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(t.md, t.md, t.md, 88),
          children: [
            _Periodo(controller: c, onData: () => _escolherData(c)),
            SizedBox(height: t.md - 4),
            TextField(
              key: const Key('campo-busca-agenda'),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Buscar cliente',
                hintText: 'Nome do cliente',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: c.buscar,
            ),
            SizedBox(height: t.md - 4),
            // Filtros logo acima da lista que eles filtram, com o contador do dia.
            _FiltroStatus(controller: c),
            SizedBox(height: t.md),
            ..._conteudo(c),
          ],
        ),
      ),
    );
  }

  List<Widget> _conteudo(AgendaAdminController c) {
    if (c.isLoading && !c.carregou) {
      return const [
        EstadoCarregando(mensagem: 'Carregando agenda', chaveIndicador: Key('agenda-carregando')),
      ];
    }
    if (c.erro != null) {
      return [
        EstadoErro(key: const Key('agenda-erro'), mensagem: c.erro!, onTentarNovamente: c.carregar),
      ];
    }
    // Espaço curto entre os itens: a grade inteira cabe em pouca rolagem.
    Widget espaco(Widget w) => Padding(padding: const EdgeInsets.only(bottom: 6), child: w);
    if (c.temFiltro) {
      final lista = c.filtrados;
      if (lista.isEmpty) {
        return [
          EstadoVazio(
            key: const Key('agenda-vazia'),
            icone: Icons.search_off,
            titulo: 'Nada encontrado',
            texto: 'Nenhum agendamento encontrado para ${Formatters.data(c.dia)}.',
          ),
        ];
      }
      return [
        for (final a in lista)
          espaco(_CardAgendamento(
            key: Key('agendamento-${a.id}'),
            agendamento: a,
            onTap: () => _abrirDetalhes(a),
          )),
      ];
    }
    return [
      for (final s in c.slots)
        espaco(s.disponivel
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
              )),
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
    final t = AppTokens.of(context);
    return Wrap(
      spacing: t.sm,
      runSpacing: t.sm,
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
          showCheckmark: false,
          avatar: const Icon(Icons.event, size: 18),
          label: Text(c.periodo == PeriodoAgenda.data ? Formatters.data(c.dia) : 'Data'),
          selected: c.periodo == PeriodoAgenda.data,
          onSelected: (_) => onData(),
        ),
      ],
    );
  }
}

/// Chips de filtro por status; cada um mostra o contador do dia (o número puro fica num
/// `Text` com Key `contador-<status>-valor`).
class _FiltroStatus extends StatelessWidget {
  const _FiltroStatus({required this.controller});

  final AgendaAdminController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final t = AppTokens.of(context);
    Widget chip({
      required String chave,
      required String chaveContador,
      required String rotulo,
      required int n,
      required bool selecionado,
      required VoidCallback onTap,
      IconData? icone,
      Color? corIcone,
    }) {
      return Padding(
        padding: EdgeInsets.only(right: t.sm),
        child: FilterChip(
          key: Key('filtro-$chave'),
          showCheckmark: false,
          selected: selecionado,
          onSelected: (_) => onTap(),
          avatar: icone == null ? null : Icon(icone, size: 18, color: corIcone),
          label: KeyedSubtree(
            key: Key('contador-$chaveContador'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(rotulo),
                SizedBox(width: t.xs + 2),
                Text(
                  '$n',
                  key: Key('contador-$chaveContador-valor'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(
            chave: 'todos',
            chaveContador: 'total',
            rotulo: 'Todos',
            n: c.total,
            selecionado: c.filtroStatus == null,
            onTap: () => c.filtrarStatus(null),
          ),
          for (final s in StatusAgendamento.conhecidos)
            chip(
              chave: s.api,
              chaveContador: s.api,
              rotulo: s.rotulo,
              n: c.contar(s),
              selecionado: c.filtroStatus == s,
              icone: s.icone,
              corIcone: s.cor(t),
              onTap: () => c.filtrarStatus(c.filtroStatus == s ? null : s),
            ),
        ],
      ),
    );
  }
}

/// Largura da coluna do horário nos itens da grade (alinha os horários entre si).
const double _larguraHorario = 64;

class _SlotDisponivel extends StatelessWidget {
  const _SlotDisponivel({super.key, required this.slot, required this.onTap});

  final SlotAgenda slot;

  /// `null` quando o horário já passou: o slot fica desabilitado, sem o "+".
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppTokens.of(context);
    final tema = Theme.of(context).textTheme;
    final n = slot.cancelados.length;
    final passou = onTap == null;
    // Itens compactos (48dp de toque) para o admin ver mais horários de uma vez.
    return Card(
      color: passou ? cs.surfaceContainerLowest : cs.surface,
      child: ListTile(
        dense: true,
        enabled: !passou,
        contentPadding: EdgeInsets.symmetric(horizontal: t.md),
        leading: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: _larguraHorario - 16),
          child: Text(slot.horario, style: tema.titleMedium, softWrap: false),
        ),
        title: Text(
          passou ? 'Horário encerrado' : 'Disponível',
          style: passou ? tema.bodyMedium : tema.bodyLarge?.copyWith(color: t.success),
        ),
        subtitle: n == 0
            ? null
            : Text(n == 1 ? '1 cancelado neste horário' : '$n cancelados neste horário'),
        trailing: passou
            ? null
            : Icon(Icons.add_circle_outline, key: const Key('slot-adicionar'), color: cs.primary),
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
    final t = AppTokens.of(context);
    final tema = Theme.of(context).textTheme;
    final horario = Text(a.horario, style: tema.titleMedium, softWrap: false);
    final pessoa = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(a.nomeCliente, style: tema.bodyLarge),
        Text(a.servico, style: tema.bodyMedium?.copyWith(color: t.onSurfaceMuted)),
      ],
    );
    // Com texto muito grande, empilha em vez de espremer numa linha só.
    final empilhar = MediaQuery.textScalerOf(context).scale(16) > 16 * 1.3;
    return Card(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: a.status.cor(t), width: 1.5),
        borderRadius: BorderRadius.circular(t.raioCard),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: t.md, vertical: t.sm + 2),
          child: empilhar
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    horario,
                    pessoa,
                    SizedBox(height: t.xs),
                    StatusChip(status: a.status),
                  ],
                )
              : Row(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: _larguraHorario - 16),
                      child: horario,
                    ),
                    SizedBox(width: t.md),
                    Expanded(child: pessoa),
                    SizedBox(width: t.sm),
                    StatusChip(status: a.status),
                  ],
                ),
        ),
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
    final cs = Theme.of(context).colorScheme;
    final t = AppTokens.of(context);
    final tema = Theme.of(context).textTheme;
    final tel = (a.telefoneCliente ?? '').trim();
    void escolher(_AcaoDetalhe acao) => Navigator.of(context).pop(acao);
    Widget linha(IconData icone, String rotulo, String valor, String chave) => Padding(
          padding: EdgeInsets.symmetric(vertical: t.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icone, size: 20, color: t.onSurfaceMuted),
              SizedBox(width: t.sm + 4),
              Expanded(
                child: Text.rich(
                  key: Key('detalhe-$chave'),
                  TextSpan(children: [
                    TextSpan(
                      text: '$rotulo: ',
                      style: tema.bodyLarge?.copyWith(color: t.onSurfaceMuted),
                    ),
                    TextSpan(text: valor, style: tema.bodyLarge),
                  ]),
                ),
              ),
            ],
          ),
        );
    final destrutivo = OutlinedButton.styleFrom(
      foregroundColor: cs.error,
      side: BorderSide(color: cs.error),
    );
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('detalhes-agendamento'),
        padding: EdgeInsets.fromLTRB(t.lg, 0, t.lg, t.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Detalhes do agendamento', style: tema.titleLarge),
            SizedBox(height: t.md - 4),
            linha(Icons.person_outline, 'Cliente', a.nomeCliente, 'cliente'),
            linha(Icons.phone_outlined, 'Telefone', tel.isEmpty ? 'Não informado' : tel, 'telefone'),
            linha(Icons.content_cut, 'Serviço', a.servico, 'servico'),
            linha(Icons.event_outlined, 'Data', Formatters.data(a.data), 'data'),
            linha(Icons.schedule, 'Horário', a.horario, 'horario'),
            SizedBox(height: t.xs),
            Row(children: [
              Text('Status: ', style: tema.bodyLarge?.copyWith(color: t.onSurfaceMuted)),
              Flexible(child: StatusChip(status: a.status)),
            ]),
            SizedBox(height: t.lg),
            // Ações do dia a dia.
            if (a.status == StatusAgendamento.pendente) ...[
              FilledButton.icon(
                key: const Key('acao-confirmar'),
                onPressed: () => escolher(_AcaoDetalhe.confirmar),
                icon: const Icon(Icons.check),
                label: const Text('Confirmar'),
              ),
              SizedBox(height: t.sm),
            ],
            if (a.status == StatusAgendamento.pendente ||
                a.status == StatusAgendamento.confirmado) ...[
              OutlinedButton.icon(
                key: const Key('acao-realizar'),
                onPressed: () => escolher(_AcaoDetalhe.realizar),
                icon: const Icon(Icons.task_alt),
                label: const Text('Marcar como realizado'),
              ),
              SizedBox(height: t.sm),
            ],
            OutlinedButton.icon(
              key: const Key('acao-editar'),
              onPressed: () => escolher(_AcaoDetalhe.editar),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar'),
            ),
            // Ações destrutivas separadas, na cor de erro.
            Padding(
              padding: EdgeInsets.symmetric(vertical: t.md - 4),
              child: const Divider(height: 1),
            ),
            if (a.status != StatusAgendamento.cancelado) ...[
              OutlinedButton.icon(
                key: const Key('acao-cancelar'),
                style: destrutivo,
                onPressed: () => escolher(_AcaoDetalhe.cancelar),
                icon: const Icon(Icons.event_busy),
                label: const Text('Cancelar'),
              ),
              SizedBox(height: t.sm),
            ],
            OutlinedButton.icon(
              key: const Key('acao-excluir'),
              style: destrutivo,
              onPressed: () => escolher(_AcaoDetalhe.excluir),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Excluir'),
            ),
            SizedBox(height: t.sm),
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
