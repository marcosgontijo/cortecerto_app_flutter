import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters/formatters.dart';
import '../../../core/router/rotas.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/validators/validators.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/botao_primario.dart';
import '../../../core/widgets/marca_cabecalho.dart';
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
  bool _senhaVisivel = false;
  bool _confirmarVisivel = false;

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

  void _irParaLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(Rotas.nomeLogin);
    }
  }

  Widget _campo({
    required String campo,
    required String label,
    required IconData icone,
    required TextEditingController controller,
    required String? Function(String?) validator,
    List<TextInputFormatter>? formatters,
    TextInputType? teclado,
    Iterable<String>? autofill,
    String? dica,
    bool? senhaVisivel,
    VoidCallback? onAlternarSenha,
    bool ultimo = false,
  }) {
    final cadastro = context.watch<CadastroController>();
    final ehSenha = senhaVisivel != null;
    return Padding(
      padding: EdgeInsets.only(bottom: AppTokens.of(context).md),
      child: TextFormField(
        key: Key('campo-$campo'),
        controller: controller,
        inputFormatters: formatters,
        keyboardType: teclado,
        obscureText: ehSenha && !senhaVisivel,
        autofillHints: autofill,
        textInputAction: ultimo ? TextInputAction.done : TextInputAction.next,
        // O "done" do último campo envia o formulário.
        onFieldSubmitted: ultimo ? (_) => cadastro.isLoading ? null : _cadastrar() : null,
        onChanged: (_) => context.read<CadastroController>().limparErroDoCampo(campo),
        decoration: InputDecoration(
          labelText: label,
          hintText: dica,
          prefixIcon: Icon(icone),
          suffixIcon: ehSenha
              ? IconButton(
                  tooltip: senhaVisivel ? 'Ocultar senha' : 'Mostrar senha',
                  icon: Icon(
                      senhaVisivel ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: onAlternarSenha,
                )
              : null,
          // Erro vindo do backend (400 errors.<campo>); o validator local tem prioridade.
          errorText: cadastro.erroDoCampo(campo),
          errorMaxLines: 3,
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CadastroController>();
    final t = AppTokens.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(t.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const MarcaCabecalho(subtitulo: 'Crie sua conta para agendar seus horários.'),
                      SizedBox(height: t.lg),
                      _campo(
                        campo: 'nome',
                        label: 'Nome completo',
                        icone: Icons.person_outline,
                        controller: _nome,
                        autofill: const [AutofillHints.name],
                        validator: (v) => Validators.obrigatorio(v, campo: 'o nome'),
                      ),
                      _campo(
                        campo: 'telefone',
                        label: 'Celular',
                        icone: Icons.phone_outlined,
                        controller: _telefone,
                        formatters: [_telefoneMask],
                        teclado: TextInputType.phone,
                        autofill: const [AutofillHints.telephoneNumber],
                        dica: '(00) 00000-0000',
                        validator: Validators.telefone,
                      ),
                      _campo(
                        campo: 'cpf',
                        label: 'CPF',
                        icone: Icons.badge_outlined,
                        controller: _cpf,
                        formatters: [_cpfMask],
                        teclado: TextInputType.number,
                        autofill: const [AutofillHints.newUsername],
                        dica: '000.000.000-00',
                        validator: Validators.cpf,
                      ),
                      _campo(
                        campo: 'email',
                        label: 'E-mail',
                        icone: Icons.email_outlined,
                        controller: _email,
                        teclado: TextInputType.emailAddress,
                        autofill: const [AutofillHints.email],
                        validator: Validators.email,
                      ),
                      _campo(
                        campo: 'dataNascimento',
                        label: 'Data de nascimento',
                        icone: Icons.cake_outlined,
                        controller: _nascimento,
                        formatters: [_dataMask],
                        teclado: TextInputType.number,
                        autofill: const [AutofillHints.birthday],
                        dica: 'dd/mm/aaaa',
                        validator: (v) => Validators.dataNascimento(v),
                      ),
                      _campo(
                        campo: 'senha',
                        label: 'Senha (mín. 8, letras e números)',
                        icone: Icons.lock_outline,
                        controller: _senha,
                        autofill: const [AutofillHints.newPassword],
                        senhaVisivel: _senhaVisivel,
                        onAlternarSenha: () => setState(() => _senhaVisivel = !_senhaVisivel),
                        validator: Validators.senha,
                      ),
                      _campo(
                        campo: 'confirmarSenha',
                        label: 'Confirmar senha',
                        icone: Icons.lock_outline,
                        controller: _confirmar,
                        autofill: const [AutofillHints.newPassword],
                        senhaVisivel: _confirmarVisivel,
                        onAlternarSenha: () =>
                            setState(() => _confirmarVisivel = !_confirmarVisivel),
                        ultimo: true,
                        validator: (v) => Validators.confirmacaoSenha(v, _senha.text),
                      ),
                      if (controller.erro != null) ...[
                        BlocoErro(key: const Key('erro-cadastro'), texto: controller.erro!),
                        SizedBox(height: t.md),
                      ],
                      BotaoPrimario(
                        key: const Key('botao-cadastrar'),
                        rotulo: 'Cadastrar',
                        enviando: controller.isLoading,
                        onPressed: _cadastrar,
                      ),
                      SizedBox(height: t.sm),
                      TextButton(
                        key: const Key('link-login'),
                        onPressed: controller.isLoading ? null : _irParaLogin,
                        child: const Text('Já tem conta? Entrar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
