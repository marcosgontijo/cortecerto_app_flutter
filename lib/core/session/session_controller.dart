import 'package:flutter/foundation.dart';

import 'jwt.dart';
import 'token_storage.dart';
import 'usuario.dart';

enum SessionStatus { desconhecida, autenticada, naoAutenticada }

/// Estado da sessão do usuário. Fonte da verdade para o redirect das rotas.
class SessionController extends ChangeNotifier {
  SessionController(this._storage, {DateTime Function()? agora})
      : _agora = agora ?? DateTime.now;

  static const String mensagemSessaoExpirada =
      'Sessão expirada, faça login novamente';

  final TokenStorage _storage;
  final DateTime Function() _agora;

  SessionStatus _status = SessionStatus.desconhecida;
  Usuario? _usuario;
  String? _mensagem;

  SessionStatus get status => _status;
  Usuario? get usuario => _usuario;
  bool get isAutenticado => _status == SessionStatus.autenticada;

  /// Aviso para mostrar na tela de Login (sessão expirada, cadastro realizado...).
  String? get mensagem => _mensagem;

  /// Lê o token salvo ao abrir o app. Token ausente, malformado ou expirado → Login.
  Future<void> restaurar() async {
    String? token;
    try {
      token = await _storage.getToken();
    } catch (_) {
      token = null;
    }
    final payload = token == null ? null : JwtPayload.tryParse(token);
    if (payload == null || payload.isExpired(_agora())) {
      if (token != null) await _limparToken();
      _usuario = null;
      _status = SessionStatus.naoAutenticada;
    } else {
      _usuario = Usuario(
        id: payload.id ?? 0,
        nome: payload.name ?? '',
        role: payload.role ?? 'CLIENTE',
      );
      _status = SessionStatus.autenticada;
    }
    notifyListeners();
  }

  /// Chamado depois de um login bem-sucedido.
  Future<void> iniciar(String token, Usuario usuario) async {
    await _storage.saveToken(token);
    _usuario = usuario;
    _mensagem = null;
    _status = SessionStatus.autenticada;
    notifyListeners();
  }

  /// Logout pedido pelo usuário.
  Future<void> sair() => _encerrar(null);

  /// 401 numa rota protegida: limpa a sessão e avisa no Login.
  Future<void> expirar() {
    if (_status != SessionStatus.autenticada) return Future.value();
    return _encerrar(mensagemSessaoExpirada);
  }

  /// Define um aviso para o Login (ex.: "Cadastro realizado").
  void avisar(String mensagem) {
    _mensagem = mensagem;
    notifyListeners();
  }

  void limparMensagem() {
    if (_mensagem == null) return;
    _mensagem = null;
    notifyListeners();
  }

  Future<void> _encerrar(String? mensagem) async {
    _usuario = null;
    _mensagem = mensagem;
    _status = SessionStatus.naoAutenticada;
    await _limparToken();
    notifyListeners();
  }

  Future<void> _limparToken() async {
    try {
      await _storage.clearToken();
    } catch (_) {
      // Falha no armazenamento seguro não deve travar o logout.
    }
  }
}
