import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../servicos/domain/servico.dart';
import 'data/agendamento_controller.dart';

class AgendamentoPage extends StatefulWidget {
  final Servico servico;

  const AgendamentoPage({
    super.key,
    required this.servico,
  });

  @override
  State<AgendamentoPage> createState() => _AgendamentoPageState();
}

class _AgendamentoPageState extends State<AgendamentoPage> {

  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        context.read<AgendamentoController>().carregarDisponibilidades());
  }

  @override
  Widget build(BuildContext context) {

    final controller = context.watch<AgendamentoController>();

    return Scaffold(
      appBar: AppBar(title: const Text("Agendamento")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text(
              "Serviço: ${widget.servico.tipoServico}",
              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: 20),

            const Text("Selecione uma data:"),

            const SizedBox(height: 10),

            if (controller.isLoading)
              const Center(child: CircularProgressIndicator()),

            if (!controller.isLoading)
              Expanded(
                child: GridView.builder(
                  itemCount: controller.disponibilidades.length,
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemBuilder: (context, index) {

                    final dia = controller.disponibilidades[index];

                    final temHorario = dia.horarios.isNotEmpty;
                    final selecionado = controller.isSameDay(
                        dia.data,
                        controller.diaSelecionado
                    );

                    return GestureDetector(
                      onTap: temHorario
                          ? () => controller.selecionarDia(dia.data)
                          : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: selecionado
                              ? Theme.of(context).colorScheme.secondary
                              : temHorario
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            "${dia.data.day}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 20),

            if (controller.diaSelecionado != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text("Horários disponíveis:"),

                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 10,
                    children: controller.horariosDisponiveis.map((horario) {

                      final selecionado =
                          horario == controller.horarioSelecionado;

                      return ChoiceChip(
                        label: Text(horario),
                        selected: selecionado,
                        onSelected: (_) =>
                            controller.selecionarHorario(horario),
                      );
                    }).toList(),
                  ),
                ],
              ),

            const Spacer(),

            if (controller.diaSelecionado != null &&
                controller.horarioSelecionado != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    controller.confirmarAgendamento(widget.servico);
                  },
                  child: const Text("Confirmar Agendamento"),
                ),
              ),
          ],
        ),
      ),
    );
  }
}