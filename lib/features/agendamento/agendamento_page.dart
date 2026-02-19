import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/presentation/login_page.dart';
import '../servicos/presentation/servico_selecionado_controller.dart';
import 'data/agendamento_controller.dart';

class AgendamentoPage extends StatelessWidget {
  const AgendamentoPage({super.key});

  void _mostrarDialogSucesso(BuildContext context, String data, String horario) {

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {

        Future.delayed(const Duration(seconds: 10), () {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
            );
          }
        });

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 70,
                ),

                const SizedBox(height: 20),

                Text(
                  "Agendamento Confirmado!",
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                Text(
                  "Seu horário foi reservado para:",
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                Text(
                  "$data às $horario",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "Você será redirecionado automaticamente...",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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
                  onPressed: () async {

                    final agendamentoController = context.read<AgendamentoController>();
                    final servico = context.read<ServicoSelecionadoController>().servico!;

                    final sucesso = await agendamentoController.confirmarAgendamento(servico);

                    if (!context.mounted) return;

                    if (sucesso) {

                      final data = agendamentoController.diaSelecionado!;
                      final horario = agendamentoController.horarioSelecionado!;

                      final dataFormatada =
                          "${data.day.toString().padLeft(2, '0')}/"
                          "${data.month.toString().padLeft(2, '0')}";

                      _mostrarDialogSucesso(context, dataFormatada, horario);

                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.red,
                          content: Text("Erro ao realizar agendamento"),
                        ),
                      );
                    }
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
