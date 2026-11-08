import 'package:flutter/foundation.dart';

import '../../../core/errors/api_exception.dart';
import '../data/auth_api.dart';
import '../domain/auth_models.dart';

class CadastroController extends ChangeNotifier {
  CadastroController(this._api);

  static const msgConflito = 'CPF ou e-mail já cadastrado';

  final AuthApi _api;

  bool _isLoading = false;
  String? _erro;
  Map<String, String> _errosPorCampo = const {};

  bool get isLoading => _isLoading;
  String? get erro => _erro;

  /// Erros do backend por campo (`nome`, `telefone`, `cpf`, `email`,
  /// `dataNascimento`, `senha`, `confirmarSenha`).
  Map<String, String> get errosPorCampo => _errosPorCampo;

  String? erroDoCampo(String campo) => _errosPorCampo[campo];

  /// Some com o erro do backend quando o usuário edita o campo.
  void limparErroDoCampo(String campo) {
    if (!_errosPorCampo.containsKey(campo)) return;
    _errosPorCampo = Map.of(_errosPorCampo)..remove(campo);
    notifyListeners();
  }

  Future<bool> cadastrar(CadastroRequest request) async {
    if (_isLoading) return false;
    _isLoading = true;
    _erro = null;
    _errosPorCampo = const {};
    notifyListeners();
    try {
      await _api.cadastrar(request);
      return true;
    } catch (e) {
      final erro = ApiErrorMapper.fromObject(e);
      _errosPorCampo = erro.errosPorCampo;
      _erro = erro.tipo == ApiErrorTipo.conflito ? msgConflito : erro.mensagem;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
