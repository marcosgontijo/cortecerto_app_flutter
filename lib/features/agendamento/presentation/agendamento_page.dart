import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/formatters/formatters.dart';
import '../../../core/router/rotas.dart';
import '../../../core/widgets/logout_button.dart';
import '../../servicos/domain/servico.dart';
import 'agendamento_controller.dart';

class AgendamentoPage extends StatefulWidget {
  const AgendamentoPage({super.key, required this.servico, this.hoje});

  final Servico servico;

  /// Data de referência (para testes). Padrão: hoje.
  final DateTime? hoje;

  /// Quantos dias à frente o calendário permite agendar.
  static const diasAFrente = 90;

  @override
  State<AgendamentoPage> createState() => _AgendamentoPageState();
}

class _AgendamentoPageState extends State<AgendamentoPage> {
  late final DateTime _hoje;
  late DateTime _foco;

  @override
  void initState() {
    super.initState();
    final agora = widget.hoje ?? DateTime.now();
    _hoje = DateTime(agora.year, agora.month, agora.day);
    _foco = _hoje;
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agendamento'),
        actions: const [LogoutButton()],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    widget.servico.tipoServico,
                    key: const Key('agendamento-servico'),
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    Formatters.precoTexto(widget.servico.precoServico),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.secondary),
                  ),
                  const SizedBox(height: 8),
                  TableCalendar<void>(
                    key: const Key('calendario'),
                    locale: 'pt_BR',
                    firstDay: _hoje,
                    lastDay: _hoje.add(const Duration(days: AgendamentoPage.diasAFrente)),
                    focusedDay: _foco,
                    currentDay: _hoje,
                    startingDayOfWeek: StartingDayOfWeek.sunday,
                    availableCalendarFormats: const {CalendarFormat.month: 'Mês'},
                    selectedDayPredicate: (d) =>
                        controller.diaSelecionado != null &&
                        isSameDay(d, controller.diaSelecionado),
                    onDaySelected: (selecionado, foco) {
                      setState(() => _foco = foco);
                      controller.selecionarDia(selecionado);
                    },
                    onPageChanged: (foco) => _foco = foco,
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                    ),
                    calendarStyle: CalendarStyle(
                      selectedDecoration:
                          BoxDecoration(color: cs.secondary, shape: BoxShape.circle),
                      todayDecoration: BoxDecoration(
                        border: Border.all(color: cs.secondary),
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: TextStyle(color: cs.onSurface),
                      disabledTextStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.3)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (controller.aviso != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        controller.aviso!,
                        key: const Key('aviso-agendamento'),
                        style: TextStyle(color: cs.secondary, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  _Horarios(controller: controller),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (controller.erroEnvio != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        controller.erroEnvio!,
                        key: const Key('erro-agendamento'),
                        style: TextStyle(color: cs.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ElevatedButton(
                    key: const Key('botao-confirmar'),
                    onPressed: controller.podeConfirmar ? _confirmar : null,
                    child: controller.enviando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Confirmar agendamento'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Horarios extends StatelessWidget {
  const _Horarios({required this.controller});

  final AgendamentoController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.diaSelecionado == null) {
      return const Text(
        'Escolha um dia no calendário para ver os horários livres.',
        key: Key('horarios-escolha-dia'),
        textAlign: TextAlign.center,
      );
    }
    if (controller.carregandoHorarios) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(key: Key('horarios-carregando')),
        ),
      );
    }
    if (controller.erroHorarios != null) {
      return Column(
        key: const Key('horarios-erro'),
        children: [
          Text(controller.erroHorarios!, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: controller.recarregarHorarios,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Tentar novamente'),
            ),
          ),
        ],
      );
    }
    if (controller.horarios.isEmpty) {
      return const Text(
        'Nenhum horário livre neste dia. Escolha outra data.',
        key: Key('horarios-vazio'),
        textAlign: TextAlign.center,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Horários livres em ${Formatters.data(controller.diaSelecionado!)}',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final h in controller.horarios)
              ChoiceChip(
                key: Key('horario-$h'),
                label: Text(h),
                selected: controller.horarioSelecionado == h,
                onSelected: controller.enviando ? null : (_) => controller.selecionarHorario(h),
              ),
          ],
        ),
      ],
    );
  }
}
