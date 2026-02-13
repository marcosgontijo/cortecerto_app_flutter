import 'package:dio/dio.dart';
import '../../../core/storage/token_storage.dart';

class ServicosApi {

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: "http://10.0.2.2:8081/api",
    ),
  );

  final TokenStorage _storage = TokenStorage();

  Future<List<dynamic>> listarServicos() async {

    final token = await _storage.getToken();

    print("TOKEN ENVIADO: $token");

    final response = await _dio.get(
      "/servicos",
      options: Options(
        headers: {
          "Authorization": "Bearer $token",
        },
      ),
    );

    return response.data;
  }
}
