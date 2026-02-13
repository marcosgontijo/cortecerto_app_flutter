import 'package:cortecerto_flutter/features/agendamento/data/agendamento_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/auth/presentation/auth_controller.dart';
import 'features/servicos/presentation/servicos_controller.dart';
import 'features/auth/presentation/login_page.dart';

void main() {
  runApp(const CorteCertoApp());
}

class CorteCertoApp extends StatelessWidget {
  const CorteCertoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => ServicosController()),
        ChangeNotifierProvider(create: (_) => AgendamentoController()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const LoginPage(),
      ),
    );
  }
}
