import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class AuthApi {

  final Dio _dio = ApiClient().dio;

  Future<Map<String, dynamic>> login(String cpf, String senha) async {

    final response = await _dio.post(
      '/clientes/login',
      data: {
        "cpf": cpf,
        "senha": senha,
      },
    );

    return response.data;
  }

  Future<void> register({
    required String nome,
    required String telefone,
    required String cpf,
    required String email,
    required String dataNascimento,
    required String senha,
    required String confirmarSenha,
  }) async {

    await _dio.post(
      '/clientes/register',
      data: {
        "nome": nome,
        "telefone": telefone,
        "cpf": cpf,
        "email": email,
        "dataNascimento": dataNascimento,
        "senha": senha,
        "confirmarSenha": confirmarSenha,
        "role": "CLIENTE",
      },
    );
  }

}
