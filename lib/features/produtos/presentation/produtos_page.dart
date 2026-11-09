import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters/formatters.dart';
import '../../../core/router/rotas.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/cliente_navigation_bar.dart';
import '../../../core/widgets/logout_button.dart';
import '../domain/produto.dart';
import 'produtos_controller.dart';

class ProdutosPage extends StatelessWidget {
  const ProdutosPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ProdutosController>();
    final theme = Theme.of(context);
    final t = AppTokens.of(context);

    // Chegamos pela barra inferior (goNamed): sem pilha, o Voltar do Android leva aos
    // serviços em vez de fechar o app.
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.goNamed(Rotas.nomeServicos);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Nossos produtos'),
          actions: const [LogoutButton()],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          // Sem o stretch a Column passa largura frouxa e a barra encolhe ao
          // tamanho do conteúdo, centralizada.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BarraTotal(controller: controller),
            const ClienteNavigationBar(atual: DestinoCliente.produtos),
          ],
        ),
        body: ListView(
          // A barra de total fica fora da lista (no rodapé do Scaffold); o espaço
          // extra no fim deixa o último item longe da borda.
          padding: EdgeInsets.fromLTRB(t.md, t.md, t.md, t.xl),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: t.onSurfaceMuted, size: 20),
                SizedBox(width: t.sm),
                Expanded(
                  child: Text(
                    'Selecione os produtos do seu interesse e confira o total. '
                    'A compra é feita na barbearia.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: t.onSurfaceMuted),
                  ),
                ),
              ],
            ),
            SizedBox(height: t.md),
            for (final p in controller.produtos) ...[
              _ProdutoCard(
                produto: p,
                selecionado: controller.isSelecionado(p),
                onAlternar: () => controller.alternar(p),
              ),
              SizedBox(height: t.md - 4),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProdutoCard extends StatelessWidget {
  const _ProdutoCard({
    required this.produto,
    required this.selecionado,
    required this.onAlternar,
  });

  final Produto produto;
  final bool selecionado;
  final VoidCallback onAlternar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppTokens.of(context);
    final tema = Theme.of(context).textTheme;
    return Card(
      // Selecionado também pela marca do checkbox (não só pela borda dourada).
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.raioCard),
        side: BorderSide(
          color: selecionado ? cs.primary : t.divider,
          width: selecionado ? 2 : 1,
        ),
      ),
      child: CheckboxListTile(
        key: Key('produto-${produto.id}'),
        value: selecionado,
        onChanged: (_) => onAlternar(),
        contentPadding: EdgeInsets.symmetric(horizontal: t.md, vertical: t.xs),
        secondary: Icon(Icons.shopping_bag_outlined, color: cs.primary),
        title: Text(produto.nome, style: tema.titleMedium),
        subtitle: Text(
          Formatters.moeda(produto.preco),
          style: tema.bodyMedium?.copyWith(color: t.onSurfaceMuted),
        ),
      ),
    );
  }
}

/// Barra fixa com a quantidade selecionada e o total.
class _BarraTotal extends StatelessWidget {
  const _BarraTotal({required this.controller});

  final ProdutosController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppTokens.of(context);
    final tema = Theme.of(context).textTheme;
    final n = controller.selecionados.length;
    return Container(
      key: const Key('produtos-barra'),
      decoration: BoxDecoration(
        color: t.surfaceHigh,
        border: Border(top: BorderSide(color: t.divider)),
      ),
      // Recuo inferior: quem trata é a NavigationBar logo abaixo (por isso bottom: false).
      // A SafeArea fica para os recuos laterais (entalhe/câmera em paisagem).
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: t.md, vertical: t.md - 4),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: t.md,
            runSpacing: t.xs,
            children: [
              Text(
                n == 1 ? '1 selecionado' : '$n selecionados',
                style: tema.bodyMedium?.copyWith(color: t.onSurfaceMuted),
              ),
              Text(
                'Total: ${Formatters.moeda(controller.total)}',
                key: const Key('produtos-total'),
                style: tema.titleMedium?.copyWith(color: cs.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
