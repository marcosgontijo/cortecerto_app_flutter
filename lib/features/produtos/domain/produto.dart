class Produto {
  const Produto({required this.id, required this.nome, required this.preco});

  final int id;
  final String nome;
  final double preco;
}

/// Catálogo local, igual ao do web (`produtos.component.ts`). Não há API de produtos.
const catalogoProdutos = <Produto>[
  Produto(id: 1, nome: 'Pomada', preco: 25.00),
  Produto(id: 2, nome: 'Shampoo', preco: 30.00),
  Produto(id: 3, nome: 'Pente', preco: 10.00),
];
