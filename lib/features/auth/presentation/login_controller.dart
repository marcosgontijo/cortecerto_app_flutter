import 'package:flutter/foundation.dart';

import '../../../core/state/notificador_seguro.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/session/session_controller.dart';
import '../data/auth_api.dart';

class LoginController extends ChangeNotifier with NotificadorSeguro {
  LoginController(this._api, this._session);

  static const msgCredenciaisInvalidas = 'CPF ou senha inválidos';

  final AuthApi _api;
  final SessionController _session;

  bool _isLoading = false;
  String? _erro;

  bool get isLoading => _isLoading;
  String? get erro => _erro;

  /// Faz o login. Só inicia a sessão (e o router só navega) se der certo.
  Future<bool> entrar({required String cpf, required String senha}) async {
    if (_isLoading) return false;
    _isLoading = true;
    _erro = null;
    _session.limparMensagem();
    notifyListeners();
    try {
      final resp = await _api.login(cpf: cpf, senha: senha);
      await _session.iniciar(resp.token, resp.usuario);
      return true;
    } catch (e) {
      final erro = ApiErrorMapper.deErro(e);
      _erro = erro.tipo == ApiErrorTipo.naoAutorizado
          ? msgCredenciaisInvalidas
          : erro.mensagem;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
