import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters/formatters.dart';
import '../../../core/widgets/logout_button.dart';
import 'produtos_controller.dart';

class ProdutosPage extends StatelessWidget {
  const ProdutosPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProdutosController>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produtos'),
        actions: const [LogoutButton()],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Selecione os produtos do seu interesse e confira o total. '
              'A compra é feita na barbearia.',
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final p in controller.produtos)
                  CheckboxListTile(
                    key: Key('produto-${p.id}'),
                    value: controller.isSelecionado(p),
                    onChanged: (_) => controller.alternar(p),
                    title: Text(p.nome),
                    subtitle: Text(Formatters.moeda(p.preco)),
                    activeColor: cs.secondary,
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${controller.selecionados.length} selecionado(s)',
                    ),
                  ),
                  Text(
                    'Total: ${Formatters.moeda(controller.total)}',
                    key: const Key('produtos-total'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: cs.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
