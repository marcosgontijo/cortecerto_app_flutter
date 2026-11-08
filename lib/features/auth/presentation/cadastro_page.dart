import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters/formatters.dart';
import '../../../core/router/rotas.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/validators/validators.dart';
import '../domain/auth_models.dart';
import 'cadastro_controller.dart';

class CadastroPage extends StatefulWidget {
  const CadastroPage({super.key});

  static const avisoSucesso = 'Cadastro realizado! Faça login para continuar.';

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _telefone = TextEditingController();
  final _cpf = TextEditingController();
  final _email = TextEditingController();
  final _nascimento = TextEditingController();
  final _senha = TextEditingController();
  final _confirmar = TextEditingController();

  final _cpfMask = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {'#': RegExp(r'[0-9]')},
  );
  final _telefoneMask = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {'#': RegExp(r'[0-9]')},
  );
  final _dataMask = MaskTextInputFormatter(
    mask: '##/##/####',
    filter: {'#': RegExp(r'[0-9]')},
  );

  @override
  void dispose() {
    for (final c in [_nome, _telefone, _cpf, _email, _nascimento, _senha, _confirmar]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cadastrar() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final controller = context.read<CadastroController>();
    final session = context.read<SessionController>();
    final nascimento = Validators.parseData(_nascimento.text)!;
    final ok = await controller.cadastrar(
      CadastroRequest(
        nome: _nome.text.trim(),
        telefone: Validators.somenteDigitos(_telefone.text),
        cpf: Validators.somenteDigitos(_cpf.text),
        email: _email.text.trim(),
        dataNascimento: Formatters.dataApi(nascimento),
        senha: _senha.text,
        confirmarSenha: _confirmar.text,
      ),
    );
    if (!ok || !mounted) return;
    session.avisar(CadastroPage.avisoSucesso);
    context.goNamed(Rotas.nomeLogin);
  }

  Widget _campo({
    required String campo,
    required String label,
    required TextEditingController controller,
    required String? Function(String?) validator,
    List<TextInputFormatter>? formatters,
    TextInputType? teclado,
    bool senha = false,
    String? dica,
  }) {
    final cadastro = context.watch<CadastroController>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: Key('campo-$campo'),
        controller: controller,
        inputFormatters: formatters,
        keyboardType: teclado,
        obscureText: senha,
        textInputAction: TextInputAction.next,
        onChanged: (_) => context.read<CadastroController>().limparErroDoCampo(campo),
        decoration: InputDecoration(
          labelText: label,
          hintText: dica,
          // Erro vindo do backend (400 errors.<campo>); o validator local tem prioridade.
          errorText: cadastro.erroDoCampo(campo),
          errorMaxLines: 2,
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CadastroController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _campo(
                campo: 'nome',
                label: 'Nome completo',
                controller: _nome,
                validator: (v) => Validators.obrigatorio(v, campo: 'o nome'),
              ),
              _campo(
                campo: 'telefone',
                label: 'Celular',
                controller: _telefone,
                formatters: [_telefoneMask],
                teclado: TextInputType.phone,
                dica: '(00) 00000-0000',
                validator: Validators.telefone,
              ),
              _campo(
                campo: 'cpf',
                label: 'CPF',
                controller: _cpf,
                formatters: [_cpfMask],
                teclado: TextInputType.number,
                dica: '000.000.000-00',
                validator: Validators.cpf,
              ),
              _campo(
                campo: 'email',
                label: 'E-mail',
                controller: _email,
                teclado: TextInputType.emailAddress,
                validator: Validators.email,
              ),
              _campo(
                campo: 'dataNascimento',
                label: 'Data de nascimento',
                controller: _nascimento,
                formatters: [_dataMask],
                teclado: TextInputType.number,
                dica: 'dd/mm/aaaa',
                validator: (v) => Validators.dataNascimento(v),
              ),
              _campo(
                campo: 'senha',
                label: 'Senha (mín. 8, letras e números)',
                controller: _senha,
                senha: true,
                validator: Validators.senha,
              ),
              _campo(
                campo: 'confirmarSenha',
                label: 'Confirmar senha',
                controller: _confirmar,
                senha: true,
                validator: (v) => Validators.confirmacaoSenha(v, _senha.text),
              ),
              if (controller.erro != null) ...[
                Text(
                  controller.erro!,
                  key: const Key('erro-cadastro'),
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                key: const Key('botao-cadastrar'),
                onPressed: controller.isLoading ? null : _cadastrar,
                child: controller.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Cadastrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
