/// Validadores dos formulários. Cada função devolve a mensagem de erro ou `null`.
class Validators {
  Validators._();

  static String somenteDigitos(String? valor) =>
      (valor ?? '').replaceAll(RegExp(r'\D'), '');

  static String? obrigatorio(String? valor, {String campo = 'o campo'}) {
    if (valor == null || valor.trim().isEmpty) return 'Informe $campo';
    return null;
  }

  /// CPF com 11 dígitos e dígitos verificadores válidos (aceita com ou sem máscara).
  static bool cpfValido(String? valor) {
    final cpf = somenteDigitos(valor);
    if (cpf.length != 11) return false;
    if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false;
    final d = cpf.split('').map(int.parse).toList();
    int digito(int tamanho) {
      var soma = 0;
      for (var i = 0; i < tamanho; i++) {
        soma += d[i] * (tamanho + 1 - i);
      }
      final resto = (soma * 10) % 11;
      return resto == 10 ? 0 : resto;
    }

    return digito(9) == d[9] && digito(10) == d[10];
  }

  static String? cpf(String? valor) {
    if (somenteDigitos(valor).isEmpty) return 'Informe o CPF';
    if (!cpfValido(valor)) return 'CPF inválido';
    return null;
  }

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? email(String? valor) {
    final v = (valor ?? '').trim();
    if (v.isEmpty) return 'Informe o e-mail';
    if (!_email.hasMatch(v)) return 'E-mail inválido';
    return null;
  }

  /// Senha com no mínimo 8 caracteres, pelo menos uma letra (A-Z, sem acento, igual ao backend) e um número.
  static String? senha(String? valor) {
    final v = valor ?? '';
    if (v.isEmpty) return 'Informe a senha';
    if (v.length < 8) return 'A senha deve ter no mínimo 8 caracteres';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'A senha deve ter letras e números';
    }
    return null;
  }

  static String? confirmacaoSenha(String? valor, String senha) {
    if ((valor ?? '').isEmpty) return 'Confirme a senha';
    if (valor != senha) return 'As senhas não conferem';
    return null;
  }

  /// Telefone com DDD: 10 ou 11 dígitos (mesma regra do backend).
  static String? telefone(String? valor) {
    final d = somenteDigitos(valor);
    if (d.isEmpty) return 'Informe o telefone';
    if (d.length < 10 || d.length > 11) {
      return 'O telefone deve ter 10 ou 11 dígitos';
    }
    return null;
  }

  /// Converte `dd/MM/aaaa` em data, ou `null` se inválida.
  static DateTime? parseData(String? valor) {
    final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch((valor ?? '').trim());
    if (m == null) return null;
    final dia = int.parse(m.group(1)!);
    final mes = int.parse(m.group(2)!);
    final ano = int.parse(m.group(3)!);
    final data = DateTime(ano, mes, dia);
    if (data.year != ano || data.month != mes || data.day != dia) return null;
    return data;
  }

  static String? dataNascimento(String? valor, {DateTime? hoje}) {
    if ((valor ?? '').trim().isEmpty) return 'Informe a data de nascimento';
    final data = parseData(valor);
    if (data == null) return 'Data inválida (use dd/mm/aaaa)';
    final ref = hoje ?? DateTime.now();
    if (!data.isBefore(DateTime(ref.year, ref.month, ref.day))) {
      return 'A data de nascimento deve estar no passado';
    }
    if (data.year < 1900) return 'Data inválida';
    return null;
  }
}
