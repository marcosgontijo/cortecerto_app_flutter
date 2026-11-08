import 'dart:async';

import 'package:cortecerto_flutter/core/errors/api_exception.dart';
import 'package:cortecerto_flutter/core/session/session_controller.dart';
import 'package:cortecerto_flutter/core/session/usuario.dart';
import 'package:cortecerto_flutter/features/auth/data/auth_api.dart';
import 'package:cortecerto_flutter/features/auth/domain/auth_models.dart';
import 'package:cortecerto_flutter/features/auth/presentation/cadastro_controller.dart';
import 'package:cortecerto_flutter/features/auth/presentation/cadastro_page.dart';
import 'package:cortecerto_flutter/features/auth/presentation/login_controller.dart';
import 'package:cortecerto_flutter/features/auth/presentation/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../helpers/fakes.dart';
import '../helpers/widget_helpers.dart';

void main() {
  late MockAuthApi api;
  late SessionController session;

  setUpAll(() => registerFallbackValue(const CadastroRequest(
        nome: '', telefone: '', cpf: '', email: '', dataNascimento: '', senha: '', confirmarSenha: '')));

  setUp(() {
    api = MockAuthApi();
    session = SessionController(FakeTokenStorage());
  });

  group('LoginPage', () {
    Widget montar() => comRouter(
          const LoginPage(),
          providers: [
            ChangeNotifierProvider<SessionController>.value(value: session),
            Provider<AuthApi>.value(value: api),
            ChangeNotifierProvider(create: (_) => LoginController(api, session)),
          ],
        );

    testWidgets('valida campos vazios', (tester) async {
      await tester.pumpWidget(montar());
      await tester.tap(find.byKey(const Key('botao-entrar')));
      await tester.pump();
      expect(find.text('Informe o CPF'), findsOneWidget);
      expect(find.text('Informe a senha'), findsOneWidget);
      verifyNever(() => api.login(cpf: any(named: 'cpf'), senha: any(named: 'senha')));
    });

    testWidgets('máscara de CPF, envia só dígitos, loading e erro 423', (tester) async {
      final completer = Completer<LoginResponse>();
      when(() => api.login(cpf: any(named: 'cpf'), senha: any(named: 'senha')))
          .thenAnswer((_) => completer.future);
      await tester.pumpWidget(montar());
      await tester.enterText(find.byKey(const Key('campo-cpf')), '52998224725');
      expect(find.text('529.982.247-25'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('campo-senha')), 'abc12345');
      await tester.tap(find.byKey(const Key('botao-entrar')));
      await tester.pump();

      verify(() => api.login(cpf: '52998224725', senha: 'abc12345')).called(1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final botao = tester.widget<ElevatedButton>(find.byKey(const Key('botao-entrar')));
      expect(botao.onPressed, isNull);

      completer.completeError(
          const ApiException(tipo: ApiErrorTipo.bloqueado, mensagem: ApiErrorMapper.msgBloqueado));
      await tester.pumpAndSettle();
      expect(find.text(ApiErrorMapper.msgBloqueado), findsOneWidget);
      expect(find.text('TELA servicos'), findsNothing);
    });

    testWidgets('401 e 429 mostram mensagens próprias', (tester) async {
      when(() => api.login(cpf: any(named: 'cpf'), senha: any(named: 'senha'))).thenThrow(
          const ApiException(tipo: ApiErrorTipo.naoAutorizado, mensagem: 'x'));
      await tester.pumpWidget(montar());
      await tester.enterText(find.byKey(const Key('campo-cpf')), '52998224725');
      await tester.enterText(find.byKey(const Key('campo-senha')), 'errada1');
      await tester.tap(find.byKey(const Key('botao-entrar')));
      await tester.pumpAndSettle();
      expect(find.text('CPF ou senha inválidos'), findsOneWidget);

      when(() => api.login(cpf: any(named: 'cpf'), senha: any(named: 'senha'))).thenThrow(
          const ApiException(
              tipo: ApiErrorTipo.muitasTentativas, mensagem: ApiErrorMapper.msgMuitasTentativas));
      await tester.tap(find.byKey(const Key('botao-entrar')));
      await tester.pumpAndSettle();
      expect(find.text(ApiErrorMapper.msgMuitasTentativas), findsOneWidget);
    });

    testWidgets('sucesso inicia a sessão', (tester) async {
      when(() => api.login(cpf: any(named: 'cpf'), senha: any(named: 'senha'))).thenAnswer(
          (_) async => const LoginResponse(
              token: 't', usuario: Usuario(id: 1, nome: 'Maria', role: 'CLIENTE')));
      await tester.pumpWidget(montar());
      await tester.enterText(find.byKey(const Key('campo-cpf')), '52998224725');
      await tester.enterText(find.byKey(const Key('campo-senha')), 'abc12345');
      await tester.tap(find.byKey(const Key('botao-entrar')));
      await tester.pumpAndSettle();
      expect(session.isAutenticado, isTrue);
    });

    testWidgets('mostra aviso da sessão e link para o cadastro', (tester) async {
      session.avisar('Sessão expirada, faça login novamente');
      await tester.pumpWidget(montar());
      expect(find.text('Sessão expirada, faça login novamente'), findsOneWidget);
      await tester.tap(find.byKey(const Key('link-cadastro')));
      await tester.pumpAndSettle();
      expect(find.text('TELA cadastro'), findsOneWidget);
    });
  });

  group('CadastroPage', () {
    Widget montar() => comRouter(
          const CadastroPage(),
          providers: [
            ChangeNotifierProvider<SessionController>.value(value: session),
            ChangeNotifierProvider(create: (_) => CadastroController(api)),
          ],
        );

    Future<void> preencher(WidgetTester tester, {String cpf = '52998224725'}) async {
      await tester.enterText(find.byKey(const Key('campo-nome')), 'Maria Silva');
      await tester.enterText(find.byKey(const Key('campo-telefone')), '11987654321');
      await tester.enterText(find.byKey(const Key('campo-cpf')), cpf);
      await tester.enterText(find.byKey(const Key('campo-email')), 'maria@mail.com');
      await tester.enterText(find.byKey(const Key('campo-dataNascimento')), '15031990');
      await tester.enterText(find.byKey(const Key('campo-senha')), 'abc12345');
      await tester.enterText(find.byKey(const Key('campo-confirmarSenha')), 'abc12345');
    }

    Future<void> enviar(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const Key('botao-cadastrar')));
      await tester.tap(find.byKey(const Key('botao-cadastrar')));
      await tester.pumpAndSettle();
    }

    testWidgets('validações locais', (tester) async {
      await tester.pumpWidget(montar());
      await preencher(tester, cpf: '12345678900');
      await tester.enterText(find.byKey(const Key('campo-email')), 'maria@');
      await tester.enterText(find.byKey(const Key('campo-senha')), 'abcdefgh');
      await tester.enterText(find.byKey(const Key('campo-confirmarSenha')), 'outra');
      await enviar(tester);
      expect(find.text('CPF inválido'), findsOneWidget);
      expect(find.text('E-mail inválido'), findsOneWidget);
      expect(find.text('A senha deve ter letras e números'), findsOneWidget);
      expect(find.text('As senhas não conferem'), findsOneWidget);
      verifyNever(() => api.cadastrar(any()));
    });

    testWidgets('400 mostra erro embaixo do campo e 409 mostra conflito', (tester) async {
      when(() => api.cadastrar(any())).thenThrow(const ApiException(
          tipo: ApiErrorTipo.dadosInvalidos,
          mensagem: ApiErrorMapper.msgDadosInvalidos,
          errosPorCampo: {'telefone': 'O telefone deve ter 10 ou 11 dígitos'}));
      await tester.pumpWidget(montar());
      await preencher(tester);
      await enviar(tester);
      expect(find.text('O telefone deve ter 10 ou 11 dígitos'), findsOneWidget);

      when(() => api.cadastrar(any()))
          .thenThrow(const ApiException(tipo: ApiErrorTipo.conflito, mensagem: 'x'));
      await enviar(tester);
      expect(find.text('CPF ou e-mail já cadastrado'), findsOneWidget);
    });

    testWidgets('sucesso envia dígitos/ISO e volta ao login com aviso', (tester) async {
      when(() => api.cadastrar(any())).thenAnswer((_) async {});
      await tester.pumpWidget(montar());
      await preencher(tester);
      await enviar(tester);
      final req = verify(() => api.cadastrar(captureAny())).captured.single as CadastroRequest;
      expect(req.cpf, '52998224725');
      expect(req.telefone, '11987654321');
      expect(req.dataNascimento, '1990-03-15');
      expect(find.text('TELA login'), findsOneWidget);
      expect(session.mensagem, contains('Cadastro realizado'));
    });
  });
}
