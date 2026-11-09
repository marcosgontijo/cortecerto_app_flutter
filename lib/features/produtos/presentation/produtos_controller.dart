import 'package:flutter/foundation.dart';

import '../../../core/state/notificador_seguro.dart';

import '../domain/produto.dart';

/// Seleção múltipla de produtos e total. Sem compra/checkout (o web também não tem).
class ProdutosController extends ChangeNotifier with NotificadorSeguro {
  ProdutosController({List<Produto> catalogo = catalogoProdutos})
      : produtos = List.unmodifiable(catalogo);

  final List<Produto> produtos;
  final Set<int> _selecionados = {};

  bool isSelecionado(Produto p) => _selecionados.contains(p.id);

  List<Produto> get selecionados =>
      produtos.where((p) => _selecionados.contains(p.id)).toList();

  double get total => selecionados.fold(0, (soma, p) => soma + p.preco);

  void alternar(Produto p) {
    if (!_selecionados.remove(p.id)) _selecionados.add(p.id);
    notifyListeners();
  }

  void limpar() {
    _selecionados.clear();
    notifyListeners();
  }
}
