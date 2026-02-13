import 'package:flutter/material.dart';
import '../../../core/storage/token_storage.dart';
import '../../domain/user_model.dart';
import '../data/auth_api.dart';

class AuthController extends ChangeNotifier {

  final AuthApi _api = AuthApi();
  final TokenStorage _storage = TokenStorage();

  Usuario? usuario;

  bool isLoading = false;
  String? error;

  bool get isLogged => usuario != null;

  // ================= LOGIN =================

  Future<bool> login(String cpf, String senha) async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      final response = await _api.login(cpf, senha);

      final token = response['token'];
      final id = response['id'];
      final nome = response['name'];
      final role = response['role'];

      await _storage.saveToken(token);

      usuario = Usuario(
        id: id,
        nome: nome,
        role: role,
      );

      return true;

    } catch (e) {
      error = "Credenciais inválidas";
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ================= REGISTER =================

  Future<bool> register({
    required String nome,
    required String telefone,
    required String cpf,
    required String email,
    required String dataNascimento,
    required String senha,
    required String confirmarSenha,
  }) async {
    try {
      isLoading = true;
      notifyListeners();

      await _api.register(
        nome: nome,
        telefone: telefone,
        cpf: cpf,
        email: email,
        dataNascimento: dataNascimento,
        senha: senha,
        confirmarSenha: confirmarSenha,
      );

      return true;

    } catch (e) {
      error = "Erro ao cadastrar";
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ================= LOGOUT =================

  Future<void> logout() async {
    await _storage.clearToken();
    usuario = null;
    notifyListeners();
  }
}
