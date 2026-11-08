import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../session/token_storage.dart';
import 'auth_interceptor.dart';

/// Único cliente HTTP do app. Todas as APIs recebem esta instância pelo construtor.
class ApiClient {
  ApiClient({
    required TokenStorage tokenStorage,
    required Future<void> Function() onUnauthorized,
    String baseUrl = ApiConfig.baseUrl,
    HttpClientAdapter? httpClientAdapter,
  }) : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: ApiConfig.connectTimeout,
            receiveTimeout: ApiConfig.receiveTimeout,
            sendTimeout: ApiConfig.sendTimeout,
            contentType: Headers.jsonContentType,
            responseType: ResponseType.json,
          ),
        ) {
    if (httpClientAdapter != null) dio.httpClientAdapter = httpClientAdapter;
    dio.interceptors.add(
      AuthInterceptor(
        tokenStorage: tokenStorage,
        onUnauthorized: onUnauthorized,
      ),
    );
  }

  final Dio dio;
}
