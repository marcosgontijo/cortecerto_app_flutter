import 'package:flutter/material.dart';
import '../domain/servico.dart';

class ServicoSelecionadoController extends ChangeNotifier {

  Servico? _servico;

  Servico? get servico => _servico;

  void selecionar(Servico servico) {
    _servico = servico;
    notifyListeners();
  }

  void limpar() {
    _servico = null;
    notifyListeners();
  }

  bool get possuiServico => _servico != null;
}
