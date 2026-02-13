import 'package:flutter/material.dart';

import '../../../core/auth/presentation/auth_controller.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {

  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _cpfController = TextEditingController();
  final _celularController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _cpfController.dispose();
    _celularController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("Cadastro")),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(32),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(40),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 20,
                  color: Colors.black26,
                  offset: Offset(0, 4),
                )
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [

                  Text(
                    "Criar Conta",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),

                  const SizedBox(height: 30),

                  _buildField("Nome Completo", _nomeController),
                  const SizedBox(height: 16),

                  _buildField("E-mail", _emailController, email: true),
                  const SizedBox(height: 16),

                  _buildField("CPF", _cpfController),
                  const SizedBox(height: 16),

                  _buildField("Celular", _celularController),
                  const SizedBox(height: 16),

                  _buildField("Senha", _senhaController, password: true),
                  const SizedBox(height: 16),

                  _buildField("Confirmar Senha", _confirmarSenhaController, password: true),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _cadastrar,
                      child: const Text("Cadastrar"),
                    ),
                  ),

                  const SizedBox(height: 20),

                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text("Já possui conta? Faça login"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
      String label,
      TextEditingController controller, {
        bool password = false,
        bool email = false,
      }) {
    return TextFormField(
      controller: controller,
      obscureText: password,
      keyboardType: email ? TextInputType.emailAddress : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return "Campo obrigatório";
        }

        if (email && !value.contains("@")) {
          return "E-mail inválido";
        }

        return null;
      },
    );
  }

  void _cadastrar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_senhaController.text != _confirmarSenhaController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("As senhas não coincidem")),
      );
      return;
    }

    final controller = AuthController();

    final success = await controller.register(
      nome: _nomeController.text,
      telefone: _celularController.text,
      cpf: _cpfController.text,
      email: _emailController.text,
      dataNascimento: "1990-01-01", // temporário
      senha: _senhaController.text,
      confirmarSenha: _confirmarSenhaController.text,
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cadastro realizado com sucesso!")),
      );

      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erro ao cadastrar")),
      );
    }
  }

}