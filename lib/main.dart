import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  final deps = AppDependencies.criar();
  // Entra direto se houver token salvo e ainda válido (exp do JWT).
  await deps.session.restaurar();
  runApp(CorteCertoApp(deps: deps));
}
