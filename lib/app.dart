import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/config/api_config.dart';
import 'core/network/api_client.dart';
import 'core/router/app_router.dart';
import 'core/session/session_controller.dart';
import 'core/session/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/data/admin_agendamento_api.dart';
import 'features/admin/data/clientes_api.dart';
import 'features/agendamento/data/agendamento_api.dart';
import 'features/auth/data/auth_api.dart';
import 'features/servicos/data/servicos_api.dart';

/// Monta o grafo de dependências do app (um único [ApiClient]/Dio para tudo).
class AppDependencies {
  AppDependencies({
    required this.session,
    required this.authApi,
    required this.servicosApi,
    required this.agendamentoApi,
    required this.adminAgendamentoApi,
    required this.clientesApi,
  });

  factory AppDependencies.criar({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    String baseUrl = ApiConfig.baseUrl,
  }) {
    final tokenStorage = TokenStorage(storage);
    final session = SessionController(tokenStorage);
    final client = ApiClient(
      tokenStorage: tokenStorage,
      baseUrl: baseUrl,
      // 401 global: limpa a sessão; o router leva ao Login com o aviso.
      onUnauthorized: session.expirar,
    );
    return AppDependencies(
      session: session,
      authApi: AuthApi(client),
      servicosApi: ServicosApi(client),
      agendamentoApi: AgendamentoApi(client),
      adminAgendamentoApi: AdminAgendamentoApi(client),
      clientesApi: ClientesApi(client),
    );
  }

  final SessionController session;
  final AuthApi authApi;
  final ServicosApi servicosApi;
  final AgendamentoApi agendamentoApi;
  final AdminAgendamentoApi adminAgendamentoApi;
  final ClientesApi clientesApi;
}

class CorteCertoApp extends StatefulWidget {
  const CorteCertoApp({super.key, required this.deps, this.localInicial});

  final AppDependencies deps;

  /// Rota inicial (útil em testes). O redirect corrige conforme a sessão.
  final String? localInicial;

  @override
  State<CorteCertoApp> createState() => _CorteCertoAppState();
}

class _CorteCertoAppState extends State<CorteCertoApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = criarRouter(widget.deps.session, localInicial: widget.localInicial);
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deps = widget.deps;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionController>.value(value: deps.session),
        Provider<AuthApi>.value(value: deps.authApi),
        Provider<ServicosApi>.value(value: deps.servicosApi),
        Provider<AgendamentoApi>.value(value: deps.agendamentoApi),
        Provider<AdminAgendamentoApi>.value(value: deps.adminAgendamentoApi),
        Provider<ClientesApi>.value(value: deps.clientesApi),
      ],
      child: MaterialApp.router(
        title: 'Corte Certo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        routerConfig: _router,
      ),
    );
  }
}
