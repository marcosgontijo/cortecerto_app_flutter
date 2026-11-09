import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/formatters/formatters.dart';
import '../../../core/router/rotas.dart';
import '../../../core/widgets/logout_button.dart';
import '../../servicos/domain/servico.dart';
import 'agendamento_controller.dart';
import '../../../core/agenda/grade_atendimento.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/botao_primario.dart';
import '../../../core/widgets/estados.dart';

class AgendamentoPage extends StatefulWidget {
  const AgendamentoPage({super.key, required this.servico, this.hoje, this.relogio});

  final Servico servico;

  /// Data fixa de referência (para testes). Tem prioridade sobre [relogio].
  final DateTime? hoje;

  /// Fonte de "agora" (para testes). Padrão: `DateTime.now`.
  final DateTime Function()? relogio;

  /// Quantos dias à frente o calendário permite agendar.
  static const diasAFrente = 90;

  @override
  State<AgendamentoPage> createState() => _AgendamentoPageState();
}

class _AgendamentoPageState extends State<AgendamentoPage> {
  late DateTime _foco;
  late final AppLifecycleListener _ciclo;

  /// "Hoje" é recalculado a cada build (não fica velho depois da meia-noite).
  DateTime get _hoje {
    final agora = widget.hoje ?? (widget.relogio ?? DateTime.now)();
    return DateTime(agora.year, agora.month, agora.day);
  }

  @override
  void initState() {
    super.initState();
    _foco = _hoje;
    // Ao voltar ao primeiro plano (ex.: no dia seguinte), redesenha com o "hoje" novo.
    _ciclo = AppLifecycleListener(onResume: () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final controller = context.read<AgendamentoController>();
    final resumo = await controller.confirmar(widget.servico);
    if (resumo == null || !mounted) return;
    context.goNamed(Rotas.nomeAgendamentoConfirmado, extra: resumo);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AgendamentoController>();
    final cs = Theme.of(context).colorScheme;
    final t = AppTokens.of(context);
    final tema = Theme.of(context).textTheme;
    final hoje = _hoje;
    final ultimoDia = hoje.add(const Duration(days: AgendamentoPage.diasAFrente));
    if (_foco.isBefore(hoje)) _foco = hoje;
    if (_foco.isAfter(ultimoDia)) _foco = ultimoDia;
    final duracao = duracaoAnimacao(context);

    final etapa = controller.horarioSelecionado != null
        ? 2
        : controller.diaSelecionado != null
            ? 1
            : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agendamento'),
        actions: const [LogoutButton()],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(t.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CabecalhoServico(servico: widget.servico),
                    SizedBox(height: t.md - 4),
                    _IndicadorEtapas(etapa: etapa, duracao: duracao),
                    SizedBox(height: t.md),
                    Card(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: t.xs, vertical: t.xs),
                        child: TableCalendar<void>(
                          key: const Key('calendario'),
                          locale: 'pt_BR',
                          firstDay: hoje,
                          lastDay: ultimoDia,
                          focusedDay: _foco,
                          currentDay: hoje,
                          startingDayOfWeek: StartingDayOfWeek.sunday,
                          availableCalendarFormats: const {CalendarFormat.month: 'Mês'},
                          rowHeight: 48,
                          daysOfWeekHeight: 24,
                          selectedDayPredicate: (d) =>
                              controller.diaSelecionado != null &&
                              isSameDay(d, controller.diaSelecionado),
                          onDaySelected: (selecionado, foco) {
                            setState(() => _foco = foco);
                            controller.selecionarDia(selecionado);
                          },
                          onPageChanged: (foco) => _foco = foco,
                          // O título padrão do pacote vem num GestureDetector com tap/longPress
                          // sempre ativos (anunciado como botão que não faz nada). Aqui ele é
                          // só texto; as setas de mês continuam sendo os únicos controles.
                          calendarBuilders: CalendarBuilders(
                            headerTitleBuilder: (context, mes) => Text(
                              DateFormat.yMMMM('pt_BR').format(mes),
                              style: tema.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          headerStyle: HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            titleTextStyle: tema.titleMedium ?? const TextStyle(),
                            leftChevronIcon: Icon(Icons.chevron_left,
                                color: cs.onSurface, semanticLabel: 'Mês anterior'),
                            rightChevronIcon: Icon(Icons.chevron_right,
                                color: cs.onSurface, semanticLabel: 'Próximo mês'),
                          ),
                          daysOfWeekStyle: DaysOfWeekStyle(
                            weekdayStyle: tema.labelMedium!.copyWith(color: t.onSurfaceMuted),
                            weekendStyle: tema.labelMedium!.copyWith(color: t.onSurfaceMuted),
                          ),
                          calendarStyle: CalendarStyle(
                            cellMargin: const EdgeInsets.all(4),
                            defaultTextStyle: tema.bodyLarge!.copyWith(color: cs.onSurface),
                            weekendTextStyle: tema.bodyLarge!.copyWith(color: cs.onSurface),
                            outsideTextStyle: tema.bodyLarge!.copyWith(color: t.onSurfaceMuted),
                            // Dias fora do intervalo: `outline` mantém contraste legível.
                            disabledTextStyle: tema.bodyLarge!.copyWith(color: cs.outline),
                            selectedDecoration:
                                BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                            selectedTextStyle: tema.bodyLarge!
                                .copyWith(color: cs.onPrimary, fontWeight: FontWeight.w700),
                            todayDecoration: BoxDecoration(
                              border: Border.all(color: cs.primary, width: 1.5),
                              shape: BoxShape.circle,
                            ),
                            todayTextStyle: tema.bodyLarge!.copyWith(color: cs.onSurface),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: t.lg),
                    if (controller.aviso != null) ...[
                      BlocoAviso(
                        key: const Key('aviso-agendamento'),
                        texto: controller.aviso!,
                        icone: Icons.warning_amber_rounded,
                      ),
                      SizedBox(height: t.md),
                    ],
                    AnimatedSwitcher(
                      duration: duracao,
                      switchInCurve: Curves.easeOut,
                      child: KeyedSubtree(
                        key: ValueKey(_estadoHorarios(controller)),
                        child: _Horarios(controller: controller),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: duracao,
                      switchInCurve: Curves.easeOut,
                      child: controller.horarioSelecionado == null
                          ? const SizedBox.shrink()
                          : Padding(
                              key: const ValueKey('resumo'),
                              padding: EdgeInsets.only(top: t.lg),
                              child: _Resumo(
                                servico: widget.servico,
                                dia: controller.diaSelecionado!,
                                horario: controller.horarioSelecionado!,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            // CTA fixo fora da rolagem.
            DecoratedBox(
              decoration: BoxDecoration(
                color: t.surfaceHigh,
                border: Border(top: BorderSide(color: t.divider)),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(t.md, t.md - 4, t.md, t.md - 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (controller.erroEnvio != null) ...[
                      BlocoErro(key: const Key('erro-agendamento'), texto: controller.erroEnvio!),
                      SizedBox(height: t.sm),
                    ],
                    BotaoPrimario(
                      key: const Key('botao-confirmar'),
                      rotulo: 'Confirmar agendamento',
                      icone: Icons.check,
                      enviando: controller.enviando,
                      onPressed: controller.podeConfirmar ? _confirmar : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Chave do conteúdo de horários: muda (e anima) só quando o estado da lista muda,
  /// não quando o usuário escolhe um horário.
  String _estadoHorarios(AgendamentoController c) {
    if (c.diaSelecionado == null) return 'escolha';
    if (c.carregandoHorarios) return 'carregando';
    if (c.erroHorarios != null) return 'erro';
    if (c.horarios.isEmpty) return 'vazio';
    return 'lista-${c.diaSelecionado}';
  }
}

/// Duração das transições: zero quando o sistema pede para desligar animações.
Duration duracaoAnimacao(BuildContext context) => MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : const Duration(milliseconds: 250);

class _CabecalhoServico extends StatelessWidget {
  const _CabecalhoServico({required this.servico});

  final Servico servico;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppTokens.of(context);
    final tema = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(t.sm),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(t.raioCampo),
          ),
          child: Icon(Icons.content_cut, color: cs.primary, size: 24),
        ),
        SizedBox(width: t.md - 4),
        Expanded(
          child: Text(
            servico.tipoServico,
            key: const Key('agendamento-servico'),
            style: tema.titleMedium,
          ),
        ),
        SizedBox(width: t.sm),
        Text(
          Formatters.precoTexto(servico.precoServico),
          style: tema.titleMedium?.copyWith(color: cs.primary),
        ),
      ],
    );
  }
}

/// Indicador Data -> Horário -> Confirmar. A etapa atual vem do estado do controller.
class _IndicadorEtapas extends StatelessWidget {
  const _IndicadorEtapas({required this.etapa, required this.duracao});

  final int etapa;
  final Duration duracao;

  static const _rotulos = ['Data', 'Horário', 'Confirmar'];
  static const _chaves = ['etapa-data', 'etapa-horario', 'etapa-confirmar'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppTokens.of(context);
    final tema = Theme.of(context).textTheme;
    // Com texto muito grande os três rótulos não cabem lado a lado: mostra só a etapa
    // atual por extenso embaixo dos marcadores.
    final compacto = MediaQuery.textScalerOf(context).scale(13) > 13 * 1.5;

    Widget linha(bool ativa) => Expanded(
          child: AnimatedContainer(
            duration: duracao,
            height: 2,
            color: ativa ? cs.primary : t.divider,
          ),
        );

    Widget passo(int i) {
      final marcador = Row(
        children: [
          if (i > 0) linha(i <= etapa) else const Spacer(),
          Icon(
            i < etapa
                ? Icons.check_circle
                : i == etapa
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
            size: 24,
            color: i <= etapa ? cs.primary : t.onSurfaceMuted,
          ),
          if (i < 2) linha(i < etapa) else const Spacer(),
        ],
      );
      return Expanded(
        child: Semantics(
          key: Key(_chaves[i]),
          label: 'Etapa ${i + 1} de 3: ${_rotulos[i]}'
              '${i < etapa ? ', concluída' : i == etapa ? ', atual' : ''}',
          selected: i == etapa,
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              marcador,
              if (!compacto) ...[
                SizedBox(height: t.xs),
                Text(
                  _rotulos[i],
                  textAlign: TextAlign.center,
                  style: tema.labelMedium?.copyWith(
                    color: i == etapa ? cs.onSurface : t.onSurfaceMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [for (var i = 0; i < 3; i++) passo(i)]),
        if (compacto) ...[
          SizedBox(height: t.xs),
          ExcludeSemantics(
            child: Text(
              'Etapa ${etapa + 1} de 3: ${_rotulos[etapa]}',
              textAlign: TextAlign.center,
              style: tema.labelMedium?.copyWith(color: cs.onSurface),
            ),
          ),
        ],
      ],
    );
  }
}

class _Horarios extends StatelessWidget {
  const _Horarios({required this.controller});

  final AgendamentoController controller;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tema = Theme.of(context).textTheme;
    if (controller.diaSelecionado == null) {
      return Row(
        children: [
          Icon(Icons.touch_app_outlined, color: t.onSurfaceMuted),
          SizedBox(width: t.sm),
          Expanded(
            child: Text(
              'Escolha um dia no calendário para ver os horários livres.',
              key: const Key('horarios-escolha-dia'),
              style: tema.bodyMedium?.copyWith(color: t.onSurfaceMuted),
            ),
          ),
        ],
      );
    }
    if (controller.carregandoHorarios) {
      return const EstadoCarregando(
        mensagem: 'Carregando horários',
        chaveIndicador: Key('horarios-carregando'),
      );
    }
    if (controller.erroHorarios != null) {
      return EstadoErro(
        key: const Key('horarios-erro'),
        mensagem: controller.erroHorarios!,
        onTentarNovamente: controller.recarregarHorarios,
      );
    }
    if (controller.horarios.isEmpty) {
      return const EstadoVazio(
        key: Key('horarios-vazio'),
        icone: Icons.event_busy,
        titulo: 'Nenhum horário livre',
        texto: 'Nenhum horário livre neste dia. Escolha outra data.',
      );
    }
    // Grade completa (D1): o que a API não devolveu aparece como indisponível.
    final livres = controller.horarios.toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Horários em ${Formatters.data(controller.diaSelecionado!)}',
          style: tema.titleMedium,
        ),
        SizedBox(height: t.xs),
        Text(
          'Toque em um horário livre. Os indisponíveis já foram reservados ou já passaram.',
          style: tema.bodyMedium?.copyWith(color: t.onSurfaceMuted),
        ),
        SizedBox(height: t.md - 4),
        Wrap(
          spacing: t.sm,
          runSpacing: t.sm,
          children: [
            for (final h in gradeComLivres(controller.horarios))
              _ChipHorario(
                horario: h,
                livre: livres.contains(h),
                selecionado: controller.horarioSelecionado == h,
                onSelecionar: controller.enviando ? null : () => controller.selecionarHorario(h),
              ),
          ],
        ),
      ],
    );
  }
}

/// Chip de horário (>= 48dp). Indisponível: desabilitado, com ícone e texto.
class _ChipHorario extends StatelessWidget {
  const _ChipHorario({
    required this.horario,
    required this.livre,
    required this.selecionado,
    required this.onSelecionar,
  });

  final String horario;
  final bool livre;
  final bool selecionado;
  final VoidCallback? onSelecionar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppTokens.of(context);
    final tema = Theme.of(context).textTheme;
    final corIcone = !livre
        ? t.onSurfaceMuted
        : selecionado
            ? cs.onSecondaryContainer
            : cs.primary;
    return ChoiceChip(
      key: Key(livre ? 'horario-$horario' : 'horario-indisponivel-$horario'),
      showCheckmark: false,
      selected: selecionado,
      onSelected: livre && onSelecionar != null ? (_) => onSelecionar!() : null,
      side: BorderSide(color: livre ? cs.outline : t.divider),
      backgroundColor: livre ? t.surfaceHigh : cs.surface,
      disabledColor: cs.surface,
      padding: EdgeInsets.symmetric(horizontal: t.xs, vertical: t.sm - 2),
      avatar: Icon(
        !livre
            ? Icons.block
            : selecionado
                ? Icons.check_circle
                : Icons.schedule,
        size: 18,
        color: corIcone,
      ),
      label: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            horario,
            style: tema.labelLarge?.copyWith(
              color: livre ? cs.onSurface : t.onSurfaceMuted,
              decoration: livre ? null : TextDecoration.lineThrough,
            ),
          ),
          Text(
            !livre
                ? 'Indisponível'
                : selecionado
                    ? 'Escolhido'
                    : 'Livre',
            style: tema.labelSmall?.copyWith(color: livre ? cs.onSurface : t.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}

/// Resumo antes de confirmar: serviço, data, horário e preço.
class _Resumo extends StatelessWidget {
  const _Resumo({required this.servico, required this.dia, required this.horario});

  final Servico servico;
  final DateTime dia;
  final String horario;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tema = Theme.of(context).textTheme;
    Widget linha(String rotulo, String valor) => Padding(
          padding: EdgeInsets.symmetric(vertical: t.xs),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '$rotulo: ', style: tema.bodyLarge?.copyWith(color: t.onSurfaceMuted)),
            TextSpan(text: valor, style: tema.titleMedium),
          ])),
        );
    return Card(
      key: const Key('agendamento-resumo'),
      child: Padding(
        padding: EdgeInsets.all(t.md),
        // stretch: o AnimatedSwitcher monta um Stack com largura frouxa; sem
        // isso o card encolhe até a linha mais larga e fica centralizado.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Resumo', style: tema.titleMedium),
            SizedBox(height: t.sm),
            linha('Serviço', servico.tipoServico),
            linha('Data', Formatters.data(dia)),
            linha('Horário', horario),
            linha('Preço', Formatters.precoTexto(servico.precoServico)),
          ],
        ),
      ),
    );
  }
}
