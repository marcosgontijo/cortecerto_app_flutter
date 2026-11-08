import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';

import '../../../core/router/rotas.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/validators/validators.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Corte Certo')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.content_cut, size: 72, color: theme.colorScheme.secondary),
                const SizedBox(height: 16),
                Text(
                  'Bem-vindo',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (aviso != null) ...[
                  _Aviso(key: const Key('aviso-login'), texto: aviso),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  key: const Key('campo-cpf'),
                  controller: _cpfController,
                  inputFormatters: [_cpfMask],
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'CPF',
                    hintText: '000.000.000-00',
                  ),
                  validator: (v) {
                    final d = Validators.somenteDigitos(v);
                    if (d.isEmpty) return 'Informe o CPF';
                    if (d.length != 11) return 'O CPF deve ter 11 dígitos';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('campo-senha'),
                  controller: _senhaController,
                  obscureText: !_senhaVisivel,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => controller.isLoading ? null : _entrar(),
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    suffixIcon: IconButton(
                      tooltip: _senhaVisivel ? 'Ocultar senha' : 'Mostrar senha',
                      icon: Icon(_senhaVisivel ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Informe a senha' : null,
                ),
                if (controller.erro != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    controller.erro!,
                    key: const Key('erro-login'),
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  key: const Key('botao-entrar'),
                  onPressed: controller.isLoading ? null : _entrar,
                  child: controller.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Entrar'),
                ),
                const SizedBox(height: 16),
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
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.secondary.withValues(alpha: 0.15),
        border: Border.all(color: cs.secondary),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: cs.secondary),
          const SizedBox(width: 8),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}
