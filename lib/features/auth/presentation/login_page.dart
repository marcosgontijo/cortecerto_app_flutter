import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';

import '../../../core/router/rotas.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/validators/validators.dart';
import '../../../core/widgets/blocos.dart';
import '../../../core/widgets/botao_primario.dart';
import '../../../core/widgets/marca_cabecalho.dart';
import 'login_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _cpfController = TextEditingController();
  final _senhaController = TextEditingController();
  final _cpfMask = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {'#': RegExp(r'[0-9]')},
  );
  bool _senhaVisivel = false;

  @override
  void dispose() {
    _cpfController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // A navegação acontece pelo redirect do router quando a sessão inicia;
    // em caso de erro, a mensagem aparece na própria tela.
    await context.read<LoginController>().entrar(
          cpf: Validators.somenteDigitos(_cpfController.text),
          senha: _senhaController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LoginController>();
    final aviso = context.watch<SessionController>().mensagem;
    final theme = Theme.of(context);
    final t = AppTokens.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: t.lg, vertical: t.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const MarcaCabecalho(),
                      SizedBox(height: t.lg),
                      Text(
                        'Bem-vindo',
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: t.xs),
                      Text(
                        'Entre com seu CPF e senha para agendar.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: t.onSurfaceMuted),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: t.lg),
                      if (aviso != null) ...[
                        BlocoAviso(key: const Key('aviso-login'), texto: aviso),
                        SizedBox(height: t.md),
                      ],
                      TextFormField(
                        key: const Key('campo-cpf'),
                        controller: _cpfController,
                        inputFormatters: [_cpfMask],
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        decoration: const InputDecoration(
                          labelText: 'CPF',
                          hintText: '000.000.000-00',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (v) {
                          final d = Validators.somenteDigitos(v);
                          if (d.isEmpty) return 'Informe o CPF';
                          if (d.length != 11) return 'O CPF deve ter 11 dígitos';
                          return null;
                        },
                      ),
                      SizedBox(height: t.md),
                      TextFormField(
                        key: const Key('campo-senha'),
                        controller: _senhaController,
                        obscureText: !_senhaVisivel,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => controller.isLoading ? null : _entrar(),
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _senhaVisivel ? 'Ocultar senha' : 'Mostrar senha',
                            icon: Icon(_senhaVisivel
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Informe a senha' : null,
                      ),
                      if (controller.erro != null) ...[
                        SizedBox(height: t.md),
                        BlocoErro(key: const Key('erro-login'), texto: controller.erro!),
                      ],
                      SizedBox(height: t.lg),
                      BotaoPrimario(
                        key: const Key('botao-entrar'),
                        rotulo: 'Entrar',
                        enviando: controller.isLoading,
                        onPressed: _entrar,
                      ),
                      SizedBox(height: t.md),
                      TextButton(
                        key: const Key('link-cadastro'),
                        onPressed: controller.isLoading
                            ? null
                            : () => context.pushNamed(Rotas.nomeCadastro),
                        child: const Text('Não tem conta? Cadastre-se'),
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
