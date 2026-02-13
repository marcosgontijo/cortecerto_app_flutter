import 'package:dio/dio.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

class ApiClient {

  late final Dio dio;

  ApiClient() {
    final tokenStorage = TokenStorage();

    dio = Dio(
      BaseOptions(
        baseUrl: "http://10.0.2.2:8081/api",
        connectTimeout: const Duration(seconds: 10),
      ),
    );

    dio.interceptors.add(AuthInterceptor(tokenStorage));
  }
}
