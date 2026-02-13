import 'package:cortecerto_flutter/features/auth/presentation/register_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cortecerto_flutter/features/servicos/presentation/servicos_page.dart';
import '../../../core/auth/presentation/auth_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  final _cpfController = TextEditingController();
  final _senhaController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _cpfController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Corte Certo"),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              const SizedBox(height: 20),

              // 🔴 Ícone estilo barber
              Icon(
                Icons.content_cut,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),

              const SizedBox(height: 30),

              // 🔵 Card de Login
              Container(
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
                        "Bem-vindo",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),

                      const SizedBox(height: 30),

                      TextFormField(
                        controller: _cpfController,
                        decoration: const InputDecoration(
                          labelText: "CPF",
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Informe o CPF";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      TextFormField(
                        controller: _senhaController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: "Senha",
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return "Informe a senha";
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {

                              print("BOTÃO CLICADO");

                              final controller = context.read<AuthController>();

                              final success = await controller.login(
                                _cpfController.text,
                                _senhaController.text,
                              );

                              if (!mounted) return;
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ServicosPage(),
                                ),
                              );
                            }
                          },
                          child: const Text("Entrar"),
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                          ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterPage(),
                                ),
                              );
                            },
                          child: const Text("Cadastrar"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
