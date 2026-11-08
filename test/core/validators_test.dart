import 'package:cortecerto_flutter/core/validators/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CPF', () {
    test('aceita CPF válido com e sem máscara', () {
      expect(Validators.cpfValido('529.982.247-25'), isTrue);
      expect(Validators.cpfValido('52998224725'), isTrue);
      expect(Validators.cpf('111.444.777-35'), isNull);
    });

    test('recusa dígito verificador errado, tamanho errado e repetidos', () {
      expect(Validators.cpfValido('52998224724'), isFalse);
      expect(Validators.cpfValido('5299822472'), isFalse);
      expect(Validators.cpfValido('11111111111'), isFalse);
      expect(Validators.cpf(''), 'Informe o CPF');
      expect(Validators.cpf('123.456.789-00'), 'CPF inválido');
    });
  });

  group('e-mail', () {
    test('valida formato', () {
      expect(Validators.email('maria@mail.com'), isNull);
      expect(Validators.email(' maria@mail.com '), isNull);
      expect(Validators.email(''), 'Informe o e-mail');
      expect(Validators.email('maria@'), 'E-mail inválido');
      expect(Validators.email('maria.mail.com'), 'E-mail inválido');
      expect(Validators.email('ma ria@mail.com'), 'E-mail inválido');
    });
  });

  group('senha', () {
    test('mínimo 8 caracteres com letra e número', () {
      expect(Validators.senha('abc12345'), isNull);
      expect(Validators.senha(''), 'Informe a senha');
      expect(Validators.senha('ab1'), contains('mínimo 8'));
      expect(Validators.senha('abcdefgh'), contains('letras e números'));
      expect(Validators.senha('12345678'), contains('letras e números'));
    });

    test('confirmação igual à senha', () {
      expect(Validators.confirmacaoSenha('abc12345', 'abc12345'), isNull);
      expect(Validators.confirmacaoSenha('', 'abc12345'), 'Confirme a senha');
      expect(Validators.confirmacaoSenha('abc12346', 'abc12345'), 'As senhas não conferem');
    });
  });

  test('telefone com 10 ou 11 dígitos', () {
    expect(Validators.telefone('(11) 98765-4321'), isNull);
    expect(Validators.telefone('1133334444'), isNull);
    expect(Validators.telefone('119876'), contains('10 ou 11'));
    expect(Validators.telefone(''), 'Informe o telefone');
  });

  test('data de nascimento dd/mm/aaaa no passado', () {
    final hoje = DateTime(2026, 11, 8);
    expect(Validators.dataNascimento('15/03/1990', hoje: hoje), isNull);
    expect(Validators.dataNascimento('', hoje: hoje), contains('Informe'));
    expect(Validators.dataNascimento('31/02/1990', hoje: hoje), contains('inválida'));
    expect(Validators.dataNascimento('08/11/2026', hoje: hoje), contains('passado'));
    expect(Validators.parseData('01/12/2000'), DateTime(2000, 12, 1));
  });
}
