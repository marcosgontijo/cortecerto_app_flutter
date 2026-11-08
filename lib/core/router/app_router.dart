import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/admin/presentation/admin_page.dart';
import '../../features/agendamento/data/agendamento_api.dart';
import '../../features/agendamento/domain/agendamento_confirmado.dart';
import '../../features/agendamento/presentation/agendamento_confirmado_page.dart';
import '../../features/agendamento/presentation/agendamento_controller.dart';
import '../../features/agendamento/presentation/agendamento_page.dart';
import '../../features/auth/data/auth_api.dart';
import '../../features/auth/presentation/cadastro_controller.dart';
import '../../features/auth/presentation/cadastro_page.dart';
import '../../features/auth/presentation/login_controller.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/produtos/presentation/produtos_controller.dart';
import '../../features/produtos/presentation/produtos_page.dart';
import '../../features/servicos/data/servicos_api.dart';
import '../../features/servicos/domain/servico.dart';
import '../../features/servicos/presentation/servicos_controller.dart';
import '../../features/servicos/presentation/servicos_page.dart';
import '../session/session_controller.dart';
import 'rotas.dart';

/// Decide para onde mandar o usuário conforme a sessão e o papel.
/// Retorna `null` quando a rota pedida pode ser exibida.
String? redirecionarPorSessao(SessionController session, String local) {
  final publica = Rotas.publicas.contains(local);
  final usuario = session.usuario;
  if (!session.isAutenticado || usuario == null) {
    return publica ? null : Rotas.login;
  }
  final inicio = usuario.isAdmin ? Rotas.admin : Rotas.servicos;
  if (publica || local == '/') return inicio;
  // Nesta fase o ADMIN só tem o painel provisório; CLIENTE nunca acessa /admin.
  if (usuario.isAdmin && local != Rotas.admin) return Rotas.admin;
  if (!usuario.isAdmin && local == Rotas.admin) return Rotas.servicos;
  return null;
}

/// Cria o router. As telas recebem controllers novos (com as APIs vindas do Provider)
/// a cada vez que a rota é aberta.
GoRouter criarRouter(SessionController session, {String? localInicial}) {
  return GoRouter(
    initialLocation: localInicial ?? Rotas.login,
    refreshListenable: session,
    redirect: (context, state) => redirecionarPorSessao(session, state.matchedLocation),
    errorBuilder: (context, state) => const _RotaNaoEncontrada(),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => Rotas.login),
      GoRoute(
        path: Rotas.login,
        name: Rotas.nomeLogin,
        builder: (context, state) => ChangeNotifierProvider(
          create: (ctx) => LoginController(ctx.read<AuthApi>(), ctx.read<SessionController>()),
          child: const LoginPage(),
        ),
      ),
      GoRoute(
        path: Rotas.cadastro,
        name: Rotas.nomeCadastro,
        builder: (context, state) => ChangeNotifierProvider(
          create: (ctx) => CadastroController(ctx.read<AuthApi>()),
          child: const CadastroPage(),
        ),
      ),
      GoRoute(
        path: Rotas.servicos,
        name: Rotas.nomeServicos,
        builder: (context, state) => ChangeNotifierProvider(
          create: (ctx) => ServicosController(ctx.read<ServicosApi>()),
          child: const ServicosPage(),
        ),
      ),
      GoRoute(
        path: Rotas.agendamento,
        name: Rotas.nomeAgendamento,
        // Sem o serviço escolhido (ex.: rota aberta direto) volta para a lista.
        redirect: (context, state) => state.extra is Servico ? null : Rotas.servicos,
        builder: (context, state) => ChangeNotifierProvider(
          create: (ctx) => AgendamentoController(ctx.read<AgendamentoApi>()),
          child: AgendamentoPage(servico: state.extra! as Servico),
        ),
      ),
      GoRoute(
        path: Rotas.agendamentoConfirmado,
        name: Rotas.nomeAgendamentoConfirmado,
        redirect: (context, state) =>
            state.extra is AgendamentoConfirmado ? null : Rotas.servicos,
        builder: (context, state) =>
            AgendamentoConfirmadoPage(resumo: state.extra! as AgendamentoConfirmado),
      ),
      GoRoute(
        path: Rotas.produtos,
        name: Rotas.nomeProdutos,
        builder: (context, state) => ChangeNotifierProvider(
          create: (_) => ProdutosController(),
          child: const ProdutosPage(),
        ),
      ),
      GoRoute(
        path: Rotas.admin,
        name: Rotas.nomeAdmin,
        builder: (context, state) => const AdminPage(),
      ),
    ],
  );
}

class _RotaNaoEncontrada extends StatelessWidget {
  const _RotaNaoEncontrada();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Página não encontrada')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => context.go('/'),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Ir para o início'),
          ),
        ),
      ),
    );
  }
}
