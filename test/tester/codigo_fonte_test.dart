// Checagens estáticas do TESTER (FASE 2) sobre lib/: um único Dio, Authorization só no
// interceptor, nada de print/log com dados pessoais, DI sem instanciar APIs em controllers/widgets,
// token só no flutter_secure_storage numa única chave.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, String> _lib() {
  final arquivos = <String, String>{};
  for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    arquivos[f.path.replaceAll('\\', '/')] = f.readAsStringSync();
  }
  return arquivos;
}

/// Remove comentários de linha (`// ...` e `/// ...`) para não contar documentação.
String _semComentarios(String s) =>
    s.split('\n').map((l) => l.replaceFirst(RegExp(r'//.*$'), '')).join('\n');

List<String> _ocorrencias(Map<String, String> lib, RegExp re) => [
      for (final e in lib.entries)
        for (final (i, l) in _semComentarios(e.value).split('\n').indexed)
          if (re.hasMatch(l)) '${e.key}:${i + 1}: ${l.trim()}'
    ];

void main() {
  final lib = _lib();

  test('lib/ foi lido', () => expect(lib, isNotEmpty));

  test('exatamente um construtor Dio( em lib/, dentro do ApiClient', () {
    final achados = _ocorrencias(lib, RegExp(r'(?<![A-Za-z0-9_])Dio\s*\('));
    expect(achados, hasLength(1), reason: achados.join('\n'));
    expect(achados.single, startsWith('lib/core/network/api_client.dart'));
  });

  test('header Authorization só no auth_interceptor', () {
    final achados = _ocorrencias(lib, RegExp(r'''Authorization|['"]Bearer'''))
        .where((l) => !l.startsWith('lib/core/network/auth_interceptor.dart'))
        .toList();
    expect(achados, isEmpty, reason: achados.join('\n'));
  });

  test('nenhum print/debugPrint/log em lib/ (nem LogInterceptor)', () {
    final achados = _ocorrencias(
        lib, RegExp(r'(?<![A-Za-z0-9_])(print|debugPrint|log)\s*\(|LogInterceptor|developer\.'));
    expect(achados, isEmpty, reason: achados.join('\n'));
  });

  test('ApiClient( e APIs só são instanciados no app.dart (composição)', () {
    final achados = _ocorrencias(
            lib, RegExp(r'(?<![A-Za-z0-9_])(ApiClient|AuthApi|ServicosApi|AgendamentoApi|AdminAgendamentoApi|ClientesApi|TokenStorage)\s*\('))
        .where((l) =>
            !l.startsWith('lib/app.dart') &&
            // declaração do próprio construtor
            !RegExp(r':\d+: (ApiClient|AuthApi|ServicosApi|AgendamentoApi|AdminAgendamentoApi|ClientesApi|TokenStorage)\(').hasMatch(l))
        .toList();
    expect(achados, isEmpty, reason: achados.join('\n'));
  });

  test('FlutterSecureStorage só no token_storage e no app.dart; sem SharedPreferences', () {
    final achados = _ocorrencias(lib, RegExp(r'FlutterSecureStorage|SharedPreferences'))
        .where((l) =>
            !l.startsWith('lib/core/session/token_storage.dart') && !l.startsWith('lib/app.dart'))
        .toList();
    expect(achados, isEmpty, reason: achados.join('\n'));
  });

  test('uma única chave de token (auth_token); a chave antiga jwt_token não existe', () {
    expect(_ocorrencias(lib, RegExp('jwt_token')), isEmpty);
    final chaves = _ocorrencias(lib, RegExp(r'''key:\s*['"]'''));
    expect(chaves, isEmpty, reason: 'chaves literais fora de TokenStorage.tokenKey: $chaves');
    expect(lib['lib/core/session/token_storage.dart'], contains("tokenKey = 'auth_token'"));
  });

  test('sem navegação imperativa antiga (Navigator.push/MaterialPageRoute)', () {
    final achados = _ocorrencias(lib, RegExp(r'Navigator\.(push|pushReplacement)|MaterialPageRoute'));
    expect(achados, isEmpty, reason: achados.join('\n'));
  });

  test('nenhuma URL com porta 8081 nem host fixo além do padrão do ApiConfig', () {
    expect(_ocorrencias(lib, RegExp('8081')), isEmpty);
    final urls = _ocorrencias(lib, RegExp(r'https?://'))
        .where((l) => !l.startsWith('lib/core/config/api_config.dart'))
        .toList();
    expect(urls, isEmpty, reason: urls.join('\n'));
  });

  test('AndroidManifest: INTERNET no main, cleartext só no debug e só para hosts locais', () {
    final main = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(main, contains('android.permission.INTERNET'));
    expect(main, isNot(contains('usesCleartextTraffic="true"')));
    expect(main, isNot(contains('networkSecurityConfig')));

    final cfgFile = File('android/app/src/debug/res/xml/network_security_config.xml');
    if (cfgFile.existsSync()) {
      final cfg = cfgFile.readAsStringSync();
      expect(cfg, isNot(contains('base-config')), reason: 'cleartext global não é permitido');
      final dominios = RegExp(r'<domain[^>]*>([^<]+)</domain>')
          .allMatches(cfg)
          .map((m) => m.group(1)!.trim())
          .toSet();
      expect(dominios.difference({'10.0.2.2', 'localhost', '127.0.0.1'}), isEmpty);
    }
    expect(File('android/app/src/main/res/xml/network_security_config.xml').existsSync(), isFalse);
  });
}
