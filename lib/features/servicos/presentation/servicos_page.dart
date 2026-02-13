import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../agendamento/agendamento_page.dart';
import 'servicos_controller.dart';
import '../domain/servico.dart';

class ServicosPage extends StatefulWidget {
  const ServicosPage({super.key});

  @override
  State<ServicosPage> createState() => _ServicosPageState();
}

class _ServicosPageState extends State<ServicosPage> {

  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        context.read<ServicosController>().carregarServicos());
  }

  @override
  Widget build(BuildContext context) {

    final controller = context.watch<ServicosController>();
    final nomeUsuario = "Usuário"; // depois pegamos do token

    return Scaffold(
      appBar: AppBar(title: const Text("Serviços")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [

            Text(
              "Selecione o serviço de hoje $nomeUsuario",
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 30),

            if (controller.isLoading)
              const CircularProgressIndicator(),

            if (!controller.isLoading)
              Expanded(
                child: GridView.builder(
                  itemCount: controller.servicos.length,
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    childAspectRatio: 0.75, // 🔥 corrigido
                  ),
                  itemBuilder: (context, index) {

                    final servico = controller.servicos[index];

                    return GestureDetector(
                      onTap: () => controller.selecionarServico(servico),
                      child: Container(
                        decoration: BoxDecoration(
                          color: servico.selecionado
                              ? Theme.of(context)
                              .colorScheme
                              .secondary
                              .withOpacity(0.2)
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: servico.selecionado
                                ? Theme.of(context).colorScheme.secondary
                                : Colors.grey.shade700,
                            width: 2,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min, // 🔥 importante
                          children: [

                            Icon(
                              _mapIcon(servico.tipoServico),
                              size: 40,
                            ),

                            const SizedBox(height: 10),

                            Text(
                              servico.tipoServico,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 8),

                            Text(
                              servico.descricao,
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 8),

                            Text(
                              "R\$ ${servico.precoServico}",
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            if (controller.temServicoSelecionado)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final servicoSelecionado = controller.servicos
                        .firstWhere((s) => s.selecionado);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AgendamentoPage(servico: servicoSelecionado),
                      ),
                    );
                  },
                  child: const Text("Agendamento"),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _mapIcon(String tipo) {
    switch (tipo) {
      case "Corte Simples":
        return Icons.content_cut;
      case "Corte + Barba":
        return Icons.face;
      case "Barba":
        return Icons.content_cut;
      default:
        return Icons.content_cut;
    }
  }
}