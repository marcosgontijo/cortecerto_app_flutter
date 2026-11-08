import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters/formatters.dart';
import '../../../core/router/rotas.dart';
import '../../../core/widgets/logout_button.dart';
import '../domain/agendamento_confirmado.dart';

class AgendamentoConfirmadoPage extends StatelessWidget {
  const AgendamentoConfirmadoPage({super.key, required this.resumo});

  final AgendamentoConfirmado resumo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agendamento confirmado'),
        automaticallyImplyLeading: false,
        actions: const [LogoutButton()],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.check_circle_outline, size: 80, color: theme.colorScheme.secondary),
              const SizedBox(height: 16),
              Text(
                'Agendamento confirmado!',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Linha(rotulo: 'Serviço', valor: resumo.servico),
                      _Linha(rotulo: 'Data', valor: Formatters.data(resumo.data)),
                      _Linha(rotulo: 'Horário', valor: resumo.horario),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                key: const Key('botao-voltar-servicos'),
                onPressed: () => context.goNamed(Rotas.nomeServicos),
                child: const Text('Voltar aos serviços'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({required this.rotulo, required this.valor});

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$rotulo: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: valor),
          ],
        ),
      ),
    );
  }
}
