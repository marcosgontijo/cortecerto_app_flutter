/// Usuário logado (dados vindos do login ou das claims do JWT).
class Usuario {
  const Usuario({required this.id, required this.nome, required this.role});

  final int id;
  final String nome;
  final String role;

  bool get isAdmin => role.toUpperCase() == 'ADMIN';
}
