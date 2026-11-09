import 'dart:async';

import 'package:cortecerto_flutter/core/errors/api_exception.dart';
import 'package:cortecerto_flutter/core/session/session_controller.dart';
import 'package:cortecerto_flutter/core/session/usuario.dart';
import 'package:cortecerto_flutter/features/admin/presentation/admin_page.dart';
import 'package:cortecerto_flutter/features/agendamento/domain/agendamento_confirmado.dart';
import 'package:cortecerto_flutter/features/agendamento/presentation/agendamento_confirmado_page.dart';
import 'package:cortecerto_flutter/features/agendamento/presentation/agendamento_controller.dart';
import 'package:cortecerto_flutter/features/agendamento/presentation/agendamento_page.dart';
import 'package:cortecerto_flutter/features/produtos/presentation/produtos_controller.dart';
import 'package:cortecerto_flutter/features/produtos/presentation/produtos_page.dart';
import 'package:cortecerto_flutter/features/servicos/domain/servico.dart';
import 'package:cortecerto_flutter/features/servicos/presentation/servicos_controller.dart';
import 'package:cortecerto_flutter/features/servicos/presentation/servicos_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../helpers/fakes.dart';
import '../helpers/widget_helpers.dart';

const _servico =
    Servico(id: 1, tipoServico: 'Corte Simples', descricao: 'Corte básico', precoServico: '35.00');

Future<void> tocar(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
}

void main() {
  late SessionController session;

  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    registerFallbackValue(_servico);
    registerFallbackValue(DateTime(2030));
  });

  setUp(() async {
    session = SessionController(FakeTokenStorage());
    await session.iniciar('t', const Usuario(id: 1, nome: 'Maria', role: 'CLIENTE'));
  });

  group('ServicosPage', () {
    late MockServicosApi api;
    setUp(() => api = MockServicosApi());

    Widget montar() => comRouter(const ServicosPage(), providers: [
          ChangeNotifierProvider<SessionController>.value(value: session),
          ChangeNotifierProvider(create: (_) => ServicosController(api)),
        ]);

    testWidgets('carregando → lista com saudação, preço e navegação', (tester) async {
      final c = Completer<List<Servico>>();
      when(() => api.listar()).thenAnswer((_) => c.future);
      await tester.pumpWidget(montar());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      c.complete([_servico]);
      await tester.pumpAndSettle();
      expect(find.text('Olá, Maria!'), findsOneWidget);
      expect(find.text('Corte Simples'), findsOneWidget);
      expect(find.text('Corte básico'), findsOneWidget);
      expect(find.text(r'R$ 35,00'), findsOneWidget);
      await tester.tap(find.text('Corte Simples'));
      await tester.pumpAndSettle();
      expect(find.text('TELA agendamento Corte Simples'), findsOneWidget);
    });

    testWidgets('erro com tentar novamente', (tester) async {
      when(() => api.listar()).thenThrow(
          const ApiException(tipo: ApiErrorTipo.semConexao, mensagem: ApiErrorMapper.msgSemConexao));
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();
      expect(find.text(ApiErrorMapper.msgSemConexao), findsOneWidget);
      when(() => api.listar()).thenAnswer((_) async => [_servico]);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('Corte Simples'), findsOneWidget);
    });

    testWidgets('vazio e botão de produtos', (tester) async {
      when(() => api.listar()).thenAnswer((_) async => []);
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('servicos-vazio')), findsOneWidget);
      await tester.tap(find.byKey(const Key('botao-produtos')));
      await tester.pumpAndSettle();
      expect(find.text('TELA produtos'), findsOneWidget);
    });

    testWidgets('logout encerra a sessão', (tester) async {
      when(() => api.listar()).thenAnswer((_) async => []);
      await tester.pumpWidget(montar());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('botao-sair')));
      await tester.pumpAndSettle();
      expect(session.isAutenticado, isFalse);
    });
  });

  group('AgendamentoPage', () {
    late MockAgendamentoApi api;
    final hoje = DateTime(2030, 1, 10);
    final dia = DateTime(2030, 1, 15);
    setUp(() => api = MockAgendamentoApi());

    Widget montar() => comRouter(AgendamentoPage(servico: _servico, hoje: hoje), providers: [
          ChangeNotifierProvider<SessionController>.value(value: session),
          ChangeNotifierProvider(create: (_) => AgendamentoController(api)),
        ]);

    testWidgets('sem dia escolhido pede para escolher; dia passado não carrega', (tester) async {
      await tester.pumpWidget(montar());
      expect(find.byKey(const Key('horarios-escolha-dia')), findsOneWidget);
      await tester.tap(find.text('5').first);
      await tester.pumpAndSettle();
      verifyNever(() => api.disponibilidades(any()));
      // FASE 4: o botão virou BotaoPrimario (FilledButton dentro do widget com a Key).
      final botao = tester.widget<ButtonStyleButton>(find.descendant(
          of: find.byKey(const Key('botao-confirmar')), matching: find.bySubtype<ButtonStyleButton>()));
      expect(botao.onPressed, isNull);
    });

    testWidgets('escolhe dia e horário e confirma', (tester) async {
      when(() => api.disponibilidades(dia)).thenAnswer((_) async => ['08:00', '08:30']);
      when(() => api.agendar(data: dia, horario: '08:30', servico: _servico))
          .thenAnswer((_) async {});
      await tester.pumpWidget(montar());
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      expect(find.text('08:00'), findsOneWidget);
      await tocar(tester, find.text('08:30'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('botao-confirmar')));
      await tester.pumpAndSettle();
      expect(find.text('TELA confirmado Corte Simples 08:30'), findsOneWidget);
    });

    testWidgets('409 avisa e recarrega; 400 mostra mensagem', (tester) async {
      var n = 0;
      when(() => api.disponibilidades(dia)).thenAnswer((_) async => ++n == 1 ? ['08:00', '08:30'] : ['08:00']);
      when(() => api.agendar(
              data: any(named: 'data'), horario: any(named: 'horario'), servico: any(named: 'servico')))
          .thenThrow(const ApiException(tipo: ApiErrorTipo.conflito, mensagem: 'Horário indisponível'));
      await tester.pumpWidget(montar());
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      await tocar(tester, find.text('08:30'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('botao-confirmar')));
      await tester.pumpAndSettle();
      expect(find.text(AgendamentoController.msgHorarioReservado), findsOneWidget);
      // FASE 4 (D1): a grade completa aparece; 08:30 deixa de ser oferecido (sem chip
      // selecionável) e fica marcado como indisponível e desabilitado.
      expect(find.byKey(const Key('horario-08:30')), findsNothing);
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('horario-indisponivel-08:30'))).onSelected,
          isNull);

      when(() => api.agendar(
              data: any(named: 'data'), horario: any(named: 'horario'), servico: any(named: 'servico')))
          .thenThrow(const ApiException(
              tipo: ApiErrorTipo.dadosInvalidos, mensagem: 'Não é possível agendar em data/horário passado'));
      await tocar(tester, find.text('08:00'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('botao-confirmar')));
      await tester.pumpAndSettle();
      expect(find.text('Não é possível agendar em data/horário passado'), findsOneWidget);
    });

    testWidgets('dia sem horários e erro ao carregar', (tester) async {
      when(() => api.disponibilidades(dia)).thenAnswer((_) async => []);
      await tester.pumpWidget(montar());
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('horarios-vazio')), findsOneWidget);

      when(() => api.disponibilidades(any())).thenThrow(
          const ApiException(tipo: ApiErrorTipo.timeout, mensagem: ApiErrorMapper.msgTimeout));
      await tester.tap(find.text('16'));
      await tester.pumpAndSettle();
      expect(find.text(ApiErrorMapper.msgTimeout), findsOneWidget);
    });
  });

  testWidgets('AgendamentoConfirmadoPage mostra resumo e volta aos serviços', (tester) async {
    await tester.pumpWidget(comRouter(
      AgendamentoConfirmadoPage(
        resumo: AgendamentoConfirmado(servico: 'Barba', data: DateTime(2030, 1, 5), horario: '09:00'),
      ),
      providers: [ChangeNotifierProvider<SessionController>.value(value: session)],
    ));
    expect(find.textContaining('Barba'), findsOneWidget);
    expect(find.textContaining('05/01/2030'), findsOneWidget);
    expect(find.textContaining('09:00'), findsOneWidget);
    await tester.tap(find.text('Voltar aos serviços'));
    await tester.pumpAndSettle();
    expect(find.text('TELA servicos'), findsOneWidget);
  });

  testWidgets('ProdutosPage: catálogo, seleção múltipla e total, sem checkout', (tester) async {
    await tester.pumpWidget(comRouter(const ProdutosPage(), providers: [
      ChangeNotifierProvider<SessionController>.value(value: session),
      ChangeNotifierProvider(create: (_) => ProdutosController()),
    ]));
    expect(find.text('Pomada'), findsOneWidget);
    expect(find.text(r'R$ 25,00'), findsOneWidget);
    expect(find.text(r'R$ 30,00'), findsOneWidget);
    expect(find.text(r'R$ 10,00'), findsOneWidget);
    expect(find.text(r'Total: R$ 0,00'), findsOneWidget);
    await tester.tap(find.text('Pomada'));
    await tester.tap(find.text('Shampoo'));
    await tester.pump();
    expect(find.text(r'Total: R$ 55,00'), findsOneWidget);
    expect(find.textContaining('Comprar'), findsNothing);
  });

  testWidgets('AdminPage provisória com nome e sair', (tester) async {
    await session.iniciar('t', const Usuario(id: 9, nome: 'Chefe', role: 'ADMIN'));
    await tester.pumpWidget(comRouter(const AdminPage(), providers: [
      ChangeNotifierProvider<SessionController>.value(value: session),
    ]));
    expect(find.text('Painel Admin'), findsOneWidget);
    expect(find.text('Olá, Chefe!'), findsOneWidget);
    await tester.tap(find.byKey(const Key('botao-sair-admin')));
    await tester.pumpAndSettle();
    expect(session.isAutenticado, isFalse);
  });
}
