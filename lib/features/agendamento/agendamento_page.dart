import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../servicos/presentation/servico_selecionado_controller.dart';
import 'data/agendamento_controller.dart';

class AgendamentoPage extends StatelessWidget {
  const AgendamentoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AgendamentoController>();

    return Scaffold(
      appBar: AppBar(title: const Text("Agendamento")),

      body: Column(
        children: [

          /// 📅 CALENDÁRIO
          CalendarDatePicker(
            initialDate: DateTime.now(),
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 60)),
            onDateChanged: (date) {
              context.read<AgendamentoController>().carregarHorarios(date);
            },
          ),

          const SizedBox(height: 20),

          /// LOADING
          if (controller.isLoading)
            const CircularProgressIndicator(),

          /// DIA LOTADO
          if (!controller.isLoading && controller.horariosDisponiveis.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 60,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Agenda cheia 😕",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Todos os horários deste dia já foram preenchidos.\nEscolha outra data.",
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          /// HORÁRIOS
          if (!controller.isLoading && controller.horariosDisponiveis.isNotEmpty)
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: controller.horariosDisponiveis.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.5,
                ),
                itemBuilder: (context, index) {

                  final horario = controller.horariosDisponiveis[index];
                  final selecionado = controller.horarioSelecionado == horario;

                  return GestureDetector(
                    onTap: () =>
                        context.read<AgendamentoController>()
                            .selecionarHorario(horario),

                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selecionado
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        horario,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: selecionado
                              ? Colors.black
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          /// ✅ BOTÃO CONFIRMAR
          if (controller.podeConfirmar)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final servico = context.read<ServicoSelecionadoController>().servico!;
                    context.read<AgendamentoController>()
                        .confirmarAgendamento(servico);

                  },
                  child: const Text("Confirmar Agendamento"),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
