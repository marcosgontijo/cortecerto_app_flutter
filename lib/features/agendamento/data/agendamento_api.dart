import 'package:dio/dio.dart';
import '../../../core/storage/token_storage.dart';
import '../../servicos/domain/servico.dart';

class AgendamentoApi {

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "http://10.0.2.2:8081/api",
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  final TokenStorage _storage = TokenStorage();

  // ==============================
  // LISTAR HORÁRIOS DISPONÍVEIS
  // ==============================
  Future<List<String>> listarDisponibilidades(DateTime data) async {

    final token = await _storage.getToken();

    final dataFormatada =
        "${data.year}-${data.month.toString().padLeft(2,'0')}-${data.day.toString().padLeft(2,'0')}";

    print("BUSCANDO DISPONIBILIDADE PARA: $dataFormatada");

    try {
      final response = await _dio.get(
        "/agendamento/disponibilidades",
        queryParameters: {"data": dataFormatada},
        options: Options(headers: {
          "Authorization": "Bearer $token",
        }),
      );

      print("HORARIOS RECEBIDOS: ${response.data}");

      return List<String>.from(response.data);

    } on DioException catch (e) {

      print("ERRO DISPONIBILIDADES: ${e.response?.statusCode}");

      if (e.response?.statusCode == 401) {
        throw Exception("Sessão expirada");
      }

      throw Exception("Erro ao carregar horários");
    }
  }


  // ==============================
  // ENVIAR AGENDAMENTO
  // ==============================
  Future<bool> enviarAgendamento({
    required DateTime data,
    required String horario,
    required Servico servico,
  }) async {

    final token = await _storage.getToken();

    final payload = {
      "data": data.toIso8601String().split("T")[0],
      "horario": horario,
      "servico": {
        "tipoServico": servico.tipoServico,
        "descricao": servico.descricao,
        "precoServico": servico.precoServico,
      },
    };

    print("ENVIANDO AGENDAMENTO: $payload");

    try {

      await _dio.post(
        "/agendamento",
        data: payload,
        options: Options(headers: {
          "Authorization": "Bearer $token",
        }),
      );

      print("AGENDAMENTO OK");
      return true;

    } on DioException catch (e) {

      final status = e.response?.statusCode;

      print("ERRO AO AGENDAR: $status");

      // 🔒 horário já reservado por outro usuário
      if (status == 409) {
        return false;
      }

      // 🔐 token expirou
      if (status == 401) {
        throw Exception("Sessão expirada");
      }

      throw Exception("Erro ao realizar agendamento");
    }
  }
}