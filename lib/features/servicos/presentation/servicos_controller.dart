import 'package:flutter/material.dart';
import '../data/servicos_api.dart';
import '../domain/servico.dart';

class ServicosController extends ChangeNotifier {

  final ServicosApi _api = ServicosApi();

  List<Servico> servicos = [];
  bool isLoading = false;
  String? error;

  Future<void> carregarServicos() async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      final data = await _api.listarServicos();

      if (data is List) {
        servicos = data
            .map<Servico>((json) => Servico.fromJson(json))
            .toList();
      } else {
        servicos = [];
      }

    } catch (e) {
      error = "Erro ao carregar serviços";
      print("ERRO SERVICOS: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
