import 'package:cortecerto_flutter/core/router/rotas.dart';
import 'package:cortecerto_flutter/core/theme/app_theme.dart';
import 'package:cortecerto_flutter/features/agendamento/domain/agendamento_confirmado.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// Monta [pagina] em `/` dentro de um GoRouter de teste, com as outras rotas
/// nomeadas como telas "stub" (texto `TELA <nome>`), para verificar navegação.
Widget comRouter(Widget pagina, {required List<SingleChildWidget> providers}) {
  Widget stub(String nome) => Scaffold(body: Text('TELA $nome'));
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => pagina),
      GoRoute(path: Rotas.login, name: Rotas.nomeLogin, builder: (_, _) => stub('login')),
      GoRoute(path: Rotas.cadastro, name: Rotas.nomeCadastro, builder: (_, _) => stub('cadastro')),
      GoRoute(path: Rotas.servicos, name: Rotas.nomeServicos, builder: (_, _) => stub('servicos')),
      GoRoute(
        path: Rotas.agendamento,
        name: Rotas.nomeAgendamento,
        builder: (_, s) => stub('agendamento ${(s.extra as dynamic)?.tipoServico}'),
      ),
      GoRoute(
        path: Rotas.agendamentoConfirmado,
        name: Rotas.nomeAgendamentoConfirmado,
        builder: (_, s) {
          final r = s.extra as AgendamentoConfirmado;
          return stub('confirmado ${r.servico} ${r.horario}');
        },
      ),
      GoRoute(path: Rotas.produtos, name: Rotas.nomeProdutos, builder: (_, _) => stub('produtos')),
      GoRoute(path: Rotas.admin, name: Rotas.nomeAdmin, builder: (_, _) => stub('admin')),
      GoRoute(
          path: Rotas.adminAgenda, name: Rotas.nomeAdminAgenda, builder: (_, _) => stub('agenda')),
      GoRoute(
        path: Rotas.adminAgendamentoForm,
        name: Rotas.nomeAdminAgendamentoForm,
        builder: (_, _) => stub('form'),
      ),
      GoRoute(
        path: Rotas.meusAgendamentos,
        name: Rotas.nomeMeusAgendamentos,
        builder: (_, _) => stub('meus'),
      ),
    ],
  );
  return MultiProvider(
    providers: providers,
    child: MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router),
  );
}
