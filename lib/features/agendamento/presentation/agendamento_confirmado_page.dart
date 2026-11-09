import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters/formatters.dart';
import '../../../core/router/rotas.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/logout_button.dart';
import '../domain/agendamento_confirmado.dart';

class AgendamentoConfirmadoPage extends StatelessWidget {
  const AgendamentoConfirmadoPage({super.key, required this.resumo});

  final AgendamentoConfirmado resumo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppTokens.of(context);
    // A pilha só tem esta tela (chegamos com goNamed): o Voltar do Android leva aos
    // serviços em vez de fechar o app.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.goNamed(Rotas.nomeServicos);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Confirmação'),
          automaticallyImplyLeading: false,
          actions: const [LogoutButton()],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(t.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.check_circle, size: 80, color: t.success),
                    SizedBox(height: t.md),
                    Semantics(
                      header: true,
                      liveRegion: true,
                      child: Text(
                        'Agendamento confirmado!',
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: t.sm),
                    Text(
                      'Seu horário foi reservado. Confira os detalhes abaixo.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: t.onSurfaceMuted),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: t.lg),
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(t.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Linha(icone: Icons.content_cut, rotulo: 'Serviço', valor: resumo.servico),
                            _Linha(
                              icone: Icons.event_outlined,
                              rotulo: 'Data',
                              valor: Formatters.data(resumo.data),
                            ),
                            _Linha(icone: Icons.schedule, rotulo: 'Horário', valor: resumo.horario),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: t.lg),
                    FilledButton.icon(
                      key: const Key('botao-meus-agendamentos'),
                      onPressed: () => context.goNamed(Rotas.nomeMeusAgendamentos),
                      icon: const Icon(Icons.event_note),
                      label: const Text('Ver meus agendamentos'),
                    ),
                    SizedBox(height: t.md - 4),
                    OutlinedButton.icon(
                      key: const Key('botao-voltar-servicos'),
                      onPressed: () => context.goNamed(Rotas.nomeServicos),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Voltar aos serviços'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({required this.icone, required this.rotulo, required this.valor});

  final IconData icone;
  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final tema = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: t.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 20, color: Theme.of(context).colorScheme.primary),
          SizedBox(width: t.sm + 4),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$rotulo: ',
                    style: tema.bodyLarge?.copyWith(color: t.onSurfaceMuted),
                  ),
                  TextSpan(text: valor, style: tema.titleMedium),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
