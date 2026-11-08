/// Configuração da API.
///
/// A URL base vem de `--dart-define=API_BASE_URL=...`. Sem o define, usa o host
/// do computador visto pelo emulador Android (`10.0.2.2`) na porta 8080.
class ApiConfig {
  ApiConfig._();

  static const String defaultBaseUrl = 'http://10.0.2.2:8080/api';

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: defaultBaseUrl,
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
  static const Duration sendTimeout = Duration(seconds: 15);
}
