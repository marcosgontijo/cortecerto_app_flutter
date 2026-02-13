import 'package:dio/dio.dart';
import '../../../core/storage/token_storage.dart';
import '../../servicos/domain/servico.dart';

class AgendamentoApi {

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "http://10.0.2.2:8081/api",
      connectTimeout: const Duration(seconds: 10),
    ),
  );

  final TokenStorage _storage = TokenStorage();

  Future<List<dynamic>> listarDisponibilidades() async {

    final token = await _storage.getToken();

    final response = await _dio.get(
      "/agendamento/disponibilidades",
      options: Options(
        headers: {
          "Authorization": "Bearer $token",
        },
      ),
    );

    return response.data;
  }

  Future<void> enviarAgendamento({
    required DateTime data,
    required String horario,
    required Servico servico,
  }) async {

    final token = await _storage.getToken();

    final payload = {
      "data": data.toIso8601String().split("T")[0], // YYYY-MM-DD
      "horario": horario,
      "servico": {
        "tipoServico": servico.tipoServico,
        "descricao": servico.descricao,
        "precoServico": servico.precoServico,
      },
      // clienteId você pode extrair do token depois
    };

    await _dio.post(
      "/agendamento",
      data: payload,
      options: Options(
        headers: {
          "Authorization": "Bearer $token",
        },
      ),
    );
  }
}
