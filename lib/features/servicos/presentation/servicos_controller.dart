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
      notifyListeners();

      final data = await _api.listarServicos();

      print("TIPO DATA: ${data.runtimeType}");
      print("DATA COMPLETA: $data");

      if (data is List) {
        servicos = data
            .map<Servico>((json) => Servico.fromJson(json))
            .toList();
      } else {
        print("DATA NÃO É LISTA!");
        servicos = [];
      }

      print("SERVICOS MAPEADOS: ${servicos.length}");

    } catch (e) {
      error = "Erro ao carregar serviços";
      print("ERRO SERVICOS: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selecionarServico(Servico selecionado) {
    for (var s in servicos) {
      s.selecionado = false;
    }
    selecionado.selecionado = true;
    notifyListeners();
  }

  bool get temServicoSelecionado =>
      servicos.any((s) => s.selecionado);
}
