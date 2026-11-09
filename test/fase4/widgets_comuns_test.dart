// FASE 4 (tester): StatusChip (ícone + texto, cor do tema), estados comuns, BotaoPrimario
// (sem toque duplo), diálogo destrutivo, feedback e a função pura da grade (D1).
import 'dart:async';

import 'package:cortecerto_flutter/core/agenda/grade_atendimento.dart';
import 'package:cortecerto_flutter/core/theme/app_theme.dart';
import 'package:cortecerto_flutter/core/theme/app_tokens.dart';
import 'package:cortecerto_flutter/core/widgets/botao_primario.dart';
import 'package:cortecerto_flutter/core/widgets/dialogo_confirmacao.dart';
import 'package:cortecerto_flutter/core/widgets/estados.dart';
import 'package:cortecerto_flutter/core/widgets/feedback.dart';
import 'package:cortecerto_flutter/features/admin/presentation/agenda_admin_controller.dart';
import 'package:cortecerto_flutter/features/agendamento/domain/status_agendamento.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget filho) => MaterialApp(theme: AppTheme.darkTheme, home: Scaffold(body: filho));

void main() {
  final tema = AppTheme.darkTheme;
  final t = tema.extension<AppTokens>()!;

  group('StatusChip', () {
    final esperado = <StatusAgendamento, (IconData, Color)>{
      StatusAgendamento.pendente: (Icons.schedule, t.warning),
      StatusAgendamento.confirmado: (Icons.check_circle, t.success),
      StatusAgendamento.realizado: (Icons.task_alt, t.info),
      StatusAgendamento.cancelado: (Icons.cancel, t.neutral),
      StatusAgendamento.desconhecido: (Icons.help_outline, t.neutral),
    };
    for (final e in esperado.entries) {
      testWidgets('${e.key.api}: ícone ${e.value.$1.codePoint} + texto, cor do token, fundo surfaceHigh',
          (tester) async {
        await tester.pumpWidget(app(Center(child: StatusChip(status: e.key))));
        final chip = find.byType(StatusChip);
        final icone = find.descendant(of: chip, matching: find.byType(Icon));
        final texto = find.descendant(of: chip, matching: find.text(e.key.rotulo));
        expect(icone, findsOneWidget);
        expect(texto, findsOneWidget);
        expect(tester.widget<Icon>(icone).icon, e.value.$1);
        expect(tester.widget<Icon>(icone).color, e.value.$2);
        expect(tester.widget<Text>(texto).style?.color, e.value.$2);
        final caixa = tester.widget<Container>(
            find.descendant(of: chip, matching: find.byType(Container)).first);
        final deco = caixa.decoration! as BoxDecoration;
        expect(deco.color, t.surfaceHigh);
      });
    }

    testWidgets('a cor vem do TEMA (trocar o token muda o chip)', (tester) async {
      const outra = Color(0xFF123456);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme.copyWith(extensions: [t.copyWith(success: outra)]),
        home: const Scaffold(body: StatusChip(status: StatusAgendamento.confirmado)),
      ));
      expect(tester.widget<Icon>(find.byIcon(Icons.check_circle)).color, outra);
    });
  });

  group('Estados comuns', () {
    testWidgets('EstadoCarregando: um único indicador centralizado com Key opcional', (tester) async {
      await tester.pumpWidget(app(const EstadoCarregando(chaveIndicador: Key('k'))));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const Key('k')), findsOneWidget);
      expect(find.ancestor(of: find.byType(CircularProgressIndicator), matching: find.byType(Center)),
          findsWidgets);
    });

    testWidgets('EstadoVazio: ícone, título, texto e ação opcional chamada 1 vez', (tester) async {
      var chamadas = 0;
      await tester.pumpWidget(app(EstadoVazio(
        icone: Icons.event_busy,
        titulo: 'Nada aqui',
        texto: 'Explicação',
        rotuloAcao: 'Agir',
        onAcao: () => chamadas++,
      )));
      expect(find.byIcon(Icons.event_busy), findsOneWidget);
      expect(find.text('Nada aqui'), findsOneWidget);
      expect(find.text('Explicação'), findsOneWidget);
      await tester.tap(find.text('Agir'));
      expect(chamadas, 1);
    });

    testWidgets('EstadoVazio sem ação não mostra botão', (tester) async {
      await tester.pumpWidget(app(const EstadoVazio(icone: Icons.inbox, titulo: 'Vazio')));
      expect(find.byType(ButtonStyleButton), findsNothing);
    });

    testWidgets('EstadoErro: mensagem e "Tentar novamente" chama o callback 1 vez', (tester) async {
      var chamadas = 0;
      await tester.pumpWidget(app(EstadoErro(mensagem: 'Falhou', onTentarNovamente: () => chamadas++)));
      expect(find.text('Falhou'), findsOneWidget);
      await tester.tap(find.text('Tentar novamente'));
      expect(chamadas, 1);
    });
  });

  group('BotaoPrimario', () {
    ButtonStyleButton botao(WidgetTester tester) => tester.widget<ButtonStyleButton>(
        find.descendant(of: find.byType(BotaoPrimario), matching: find.bySubtype<ButtonStyleButton>()));

    testWidgets('dois toques antes de terminar = UMA chamada; indicador e desabilitado durante o envio',
        (tester) async {
      final c = Completer<void>();
      var chamadas = 0;
      await tester.pumpWidget(app(BotaoPrimario(
        rotulo: 'Enviar',
        onPressed: () {
          chamadas++;
          return c.future;
        },
      )));
      expect(botao(tester), isA<FilledButton>());
      await tester.tap(find.byType(BotaoPrimario));
      await tester.tap(find.byType(BotaoPrimario), warnIfMissed: false);
      await tester.pump();
      await tester.tap(find.byType(BotaoPrimario), warnIfMissed: false);
      await tester.pump();
      expect(chamadas, 1);
      expect(botao(tester).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Enviar'), findsNothing);
      c.complete();
      await tester.pumpAndSettle();
      expect(botao(tester).onPressed, isNotNull);
      expect(find.text('Enviar'), findsOneWidget);
      await tester.tap(find.byType(BotaoPrimario));
      expect(chamadas, 2);
    });

    testWidgets('enviando=true: indicador e onPressed null', (tester) async {
      await tester.pumpWidget(app(BotaoPrimario(rotulo: 'X', enviando: true, onPressed: () {})));
      expect(botao(tester).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('onPressed null: desabilitado sem indicador', (tester) async {
      await tester.pumpWidget(app(const BotaoPrimario(rotulo: 'X', onPressed: null)));
      expect(botao(tester).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('altura >= 52 (tema)', (tester) async {
      await tester.pumpWidget(app(Center(child: BotaoPrimario(rotulo: 'X', onPressed: () {}))));
      expect(tester.getSize(find.bySubtype<ButtonStyleButton>()).height, greaterThanOrEqualTo(52));
    });
  });

  group('confirmarAcao', () {
    Future<Future<bool>> abrir(WidgetTester tester, {bool destrutivo = true}) async {
      late Future<bool> r;
      await tester.pumpWidget(app(Builder(
        builder: (ctx) => TextButton(
          onPressed: () => r = confirmarAcao(ctx,
              titulo: 'Cancelar?', mensagem: 'Tem certeza?', rotuloConfirmar: 'Sim', destrutivo: destrutivo),
          child: const Text('abrir'),
        ),
      )));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      return r;
    }

    testWidgets('destrutivo: botão dialogo-sim na cor error (resolvida) e devolve true', (tester) async {
      final r = await abrir(tester);
      final sim = tester.widget<TextButton>(find.byKey(const Key('dialogo-sim')));
      expect(sim.style?.foregroundColor?.resolve(<WidgetState>{}), tema.colorScheme.error);
      // a cor renderizada do texto também é error
      final txt = tester.widget<RichText>(
          find.descendant(of: find.byKey(const Key('dialogo-sim')), matching: find.byType(RichText)));
      expect(txt.text.style?.color, tema.colorScheme.error);
      await tester.tap(find.byKey(const Key('dialogo-sim')));
      await tester.pumpAndSettle();
      expect(await r, isTrue);
    });

    testWidgets('"Voltar" (dialogo-nao) devolve false', (tester) async {
      final r = await abrir(tester);
      expect(find.text('Voltar'), findsOneWidget);
      await tester.tap(find.byKey(const Key('dialogo-nao')));
      await tester.pumpAndSettle();
      expect(await r, isFalse);
    });

    testWidgets('tocar fora devolve false', (tester) async {
      final r = await abrir(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(await r, isFalse);
    });

    testWidgets('não destrutivo não pinta de error', (tester) async {
      await abrir(tester, destrutivo: false);
      final sim = tester.widget<TextButton>(find.byKey(const Key('dialogo-sim')));
      expect(sim.style, isNull);
    });
  });

  group('mostrarFeedback', () {
    testWidgets('sucesso e erro: Keys, flutuante, erro em error/onError', (tester) async {
      await tester.pumpWidget(app(Builder(
        builder: (ctx) => Column(children: [
          TextButton(onPressed: () => mostrarFeedback(ctx, 'ok'), child: const Text('s')),
          TextButton(onPressed: () => mostrarFeedback(ctx, 'ruim', erro: true), child: const Text('e')),
        ]),
      )));
      await tester.tap(find.text('s'));
      await tester.pump();
      expect(find.byKey(const Key('snack-sucesso')), findsOneWidget);
      expect(find.text('ok'), findsOneWidget);
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).behavior ?? tema.snackBarTheme.behavior,
          SnackBarBehavior.floating);
      await tester.tap(find.text('e'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('snack-erro')), findsOneWidget);
      final snack = tester.widget<SnackBar>(find.byKey(const Key('snack-erro')));
      expect(snack.backgroundColor, tema.colorScheme.error);
      expect(tester.widget<Text>(find.text('ruim')).style?.color, tema.colorScheme.onError);
      expect(find.byKey(const Key('snack-sucesso')), findsNothing); // não acumula
    });
  });

  group('grade de atendimento (D1)', () {
    test('08:00 a 19:30 de 30 em 30, 24 horários, em ordem', () {
      final g = gerarGradeAtendimento();
      expect(g.length, 24);
      expect(g.first, '08:00');
      expect(g[1], '08:30');
      expect(g.last, '19:30');
      expect(g, contains('12:00'));
      expect(g, isNot(contains('20:00')));
      expect(g, isNot(contains('07:30')));
      expect([...g]..sort(), g);
    });

    test('a Agenda Admin usa a mesma grade (sem mudança de comportamento)', () {
      expect(AgendaAdminController.grade, gerarGradeAtendimento());
    });

    test('gradeComLivres: união ordenada, sem duplicata, inclui horário fora da grade', () {
      final g = gradeComLivres(['09:00', '20:15', '07:45']);
      expect(g.length, 26);
      expect(g.first, '07:45');
      expect(g.last, '20:15');
      expect(g.where((h) => h == '09:00').length, 1);
      expect([...g]..sort(), g);
      expect(gradeComLivres(const []), gerarGradeAtendimento());
    });
  });
}
