import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/rotas.dart';

/// Destinos da barra inferior do cliente.
enum DestinoCliente { servicos, meusAgendamentos, produtos }

/// Barra de navegação inferior do cliente (Serviços, Meus agendamentos, Produtos).
/// Usada no `bottomNavigationBar` das três páginas; navega com `goNamed` pelos
/// mesmos paths de sempre (sem ShellRoute, sem mudar rotas nem redirects).
class ClienteNavigationBar extends StatelessWidget {
  const ClienteNavigationBar({super.key, required this.atual});

  final DestinoCliente atual;

  static const _nomes = {
    DestinoCliente.servicos: Rotas.nomeServicos,
    DestinoCliente.meusAgendamentos: Rotas.nomeMeusAgendamentos,
    DestinoCliente.produtos: Rotas.nomeProdutos,
  };

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: atual.index,
      onDestinationSelected: (i) {
        final destino = DestinoCliente.values[i];
        if (destino == atual) return;
        context.goNamed(_nomes[destino]!);
      },
      destinations: const [
        NavigationDestination(
          key: Key('nav-servicos'),
          icon: Icon(Icons.content_cut_outlined),
          selectedIcon: Icon(Icons.content_cut),
          label: 'Serviços',
        ),
        NavigationDestination(
          key: Key('botao-meus-agendamentos'),
          icon: Icon(Icons.event_note_outlined),
          selectedIcon: Icon(Icons.event_note),
          label: 'Meus agendamentos',
        ),
        NavigationDestination(
          key: Key('botao-produtos'),
          icon: Icon(Icons.shopping_bag_outlined),
          selectedIcon: Icon(Icons.shopping_bag),
          label: 'Produtos',
        ),
      ],
    );
  }
}
