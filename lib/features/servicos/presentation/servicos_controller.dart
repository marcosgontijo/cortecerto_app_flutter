import 'package:flutter/foundation.dart';

import '../../../core/errors/api_exception.dart';
import '../data/servicos_api.dart';
import '../domain/servico.dart';

class ServicosController extends ChangeNotifier {
  ServicosController(this._api);

  final ServicosApi _api;

  bool _isLoading = false;
  String? _erro;
  List<Servico> _servicos = const [];
  bool _carregou = false;

  bool get isLoading => _isLoading;
  String? get erro => _erro;
  List<Servico> get servicos => _servicos;

  /// Carregou com sucesso e a lista veio vazia.
  bool get isVazio => _carregou && _erro == null && _servicos.isEmpty;

  Future<void> carregarServicos() async {
    if (_isLoading) return;
    _isLoading = true;
    _erro = null;
    notifyListeners();
    try {
      _servicos = await _api.listar();
      _carregou = true;
    } catch (e) {
      _erro = ApiErrorMapper.fromObject(e).mensagem;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
