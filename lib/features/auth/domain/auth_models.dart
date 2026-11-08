import '../../../core/session/usuario.dart';

/// Resposta do `POST /clientes/login`: `{token, id, name, role}`.
class LoginResponse {
  const LoginResponse({required this.token, required this.usuario});

  final String token;
  final Usuario usuario;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    return LoginResponse(
      token: (json['token'] ?? '').toString(),
      usuario: Usuario(
        id: id is num ? id.toInt() : int.tryParse('$id') ?? 0,
        nome: (json['name'] ?? json['nome'] ?? '').toString(),
        role: (json['role'] ?? 'CLIENTE').toString(),
      ),
    );
  }
}

/// Corpo do `POST /clientes/register`.
class CadastroRequest {
  const CadastroRequest({
    required this.nome,
    required this.telefone,
    required this.cpf,
    required this.email,
    required this.dataNascimento,
    required this.senha,
    required this.confirmarSenha,
  });

  final String nome;

  /// Só dígitos.
  final String telefone;

  /// Só dígitos.
  final String cpf;
  final String email;

  /// `AAAA-MM-DD`.
  final String dataNascimento;
  final String senha;
  final String confirmarSenha;

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'telefone': telefone,
        'cpf': cpf,
        'email': email,
        'dataNascimento': dataNascimento,
        'senha': senha,
        'confirmarSenha': confirmarSenha,
      };
}
