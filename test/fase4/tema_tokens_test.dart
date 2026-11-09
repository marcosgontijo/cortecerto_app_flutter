// FASE 4 (tester): tokens do MASTER.md, escala tipográfica, temas de componente e
// contraste WCAG calculado a partir do tema REAL (AppTheme.darkTheme + AppTokens),
// nunca de constantes copiadas no teste.
import 'package:cortecerto_flutter/core/theme/app_theme.dart';
import 'package:cortecerto_flutter/core/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Razão de contraste WCAG 2.x: (L1 + 0.05) / (L2 + 0.05), L1 a maior luminância.
double contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final maior = la > lb ? la : lb;
  final menor = la > lb ? lb : la;
  return (maior + 0.05) / (menor + 0.05);
}

int hex(Color c) => c.toARGB32();

void main() {
  final tema = AppTheme.darkTheme;
  final cs = tema.colorScheme;
  final t = tema.extension<AppTokens>()!;
  final fundo = tema.scaffoldBackgroundColor;

  group('1.1 tokens do MASTER', () {
    test('ColorScheme escuro com os hex da tabela', () {
      expect(cs.brightness, Brightness.dark);
      expect(tema.brightness, Brightness.dark);
      expect(hex(cs.primary), 0xFFD4A017);
      expect(hex(cs.onPrimary), 0xFF0C0A09);
      expect(hex(cs.surface), 0xFF1C1917);
      expect(hex(cs.onSurface), 0xFFFAFAF9);
      expect(hex(cs.error), 0xFFF87171);
      expect(hex(cs.onError), 0xFF0C0A09);
      expect(hex(cs.outline), 0xFF8A837E);
      expect(hex(cs.outlineVariant), 0xFF44403C);
      expect(hex(cs.surfaceContainerHigh), 0xFF292524);
      expect(hex(cs.surfaceContainerHighest), 0xFF292524);
      expect(hex(fundo), 0xFF0C0A09);
    });

    test('ThemeExtension AppTokens registrada com status, muted, surfaceHigh, espaços e raios', () {
      expect(tema.extensions.values.whereType<AppTokens>(), hasLength(1));
      expect(hex(t.success), 0xFF4ADE80);
      expect(hex(t.warning), 0xFFFBBF24);
      expect(hex(t.info), 0xFF60A5FA);
      expect(hex(t.neutral), 0xFFA8A29E);
      expect(hex(t.onSurfaceMuted), 0xFFA8A29E);
      expect(hex(t.surfaceHigh), 0xFF292524);
      expect(hex(t.divider), 0xFF44403C);
      expect([t.xs, t.sm, t.md, t.lg, t.xl, t.xxl], [4, 8, 16, 24, 32, 48]);
      expect([t.raioCampo, t.raioCard, t.raioChip, t.raioSheet], [12, 16, 999, 24]);
    });

    test('copyWith e lerp funcionam (exigência de ThemeExtension)', () {
      final c = t.copyWith(success: const Color(0xFF000000), md: 20);
      expect(hex(c.success), 0xFF000000);
      expect(c.md, 20);
      expect(hex(c.warning), hex(t.warning));
      final meio = t.lerp(c, 0.5);
      expect(meio.md, 18);
      expect(identical(t.lerp(null, 0.5), t), isTrue);
    });
  });

  group('1.2 TextTheme', () {
    test('escala do MASTER', () {
      final tt = tema.textTheme;
      void confere(TextStyle? s, double tam, FontWeight peso, [double? altura]) {
        expect(s, isNotNull);
        expect(s!.fontSize, tam);
        expect(s.fontWeight, peso);
        if (altura != null) expect(s.height, altura);
      }

      confere(tt.headlineSmall, 24, FontWeight.w700);
      confere(tt.titleLarge, 20, FontWeight.w600);
      confere(tt.titleMedium, 16, FontWeight.w600);
      confere(tt.bodyLarge, 16, FontWeight.w400, 1.5);
      confere(tt.bodyMedium, 14, FontWeight.w400, 1.45);
      confere(tt.labelLarge, 16, FontWeight.w600);
      confere(tt.labelMedium, 13, FontWeight.w600);
    });

    test('nenhum estilo do TextTheme abaixo de 12', () {
      final tt = tema.textTheme;
      final todos = <String, TextStyle?>{
        'displayLarge': tt.displayLarge, 'displayMedium': tt.displayMedium,
        'displaySmall': tt.displaySmall, 'headlineLarge': tt.headlineLarge,
        'headlineMedium': tt.headlineMedium, 'headlineSmall': tt.headlineSmall,
        'titleLarge': tt.titleLarge, 'titleMedium': tt.titleMedium, 'titleSmall': tt.titleSmall,
        'bodyLarge': tt.bodyLarge, 'bodyMedium': tt.bodyMedium, 'bodySmall': tt.bodySmall,
        'labelLarge': tt.labelLarge, 'labelMedium': tt.labelMedium, 'labelSmall': tt.labelSmall,
      };
      for (final e in todos.entries) {
        expect(e.value?.fontSize, isNotNull, reason: '${e.key} sem fontSize');
        expect(e.value!.fontSize, greaterThanOrEqualTo(12), reason: e.key);
      }
    });
  });

  group('1.3 temas de componente', () {
    test('todos configurados', () {
      expect(tema.filledButtonTheme.style, isNotNull);
      expect(tema.outlinedButtonTheme.style, isNotNull);
      expect(tema.textButtonTheme.style, isNotNull);
      expect(tema.inputDecorationTheme.border, isNotNull);
      expect(tema.inputDecorationTheme.filled, isTrue);
      expect(tema.cardTheme.shape, isNotNull);
      expect(tema.chipTheme.backgroundColor, isNotNull);
      expect(tema.appBarTheme.backgroundColor, isNotNull);
      expect(tema.navigationBarTheme.indicatorColor, isNotNull);
      expect(tema.snackBarTheme.behavior, SnackBarBehavior.floating);
      expect(tema.dialogTheme.shape, isNotNull);
      expect(tema.floatingActionButtonTheme.backgroundColor, isNotNull);
    });

    test('botão primário: altura mínima 52 e raio 12; card com raio 16', () {
      final s = tema.filledButtonTheme.style!;
      final tam = s.minimumSize!.resolve(<WidgetState>{})!;
      expect(tam.height, greaterThanOrEqualTo(52));
      final forma = s.shape!.resolve(<WidgetState>{})! as RoundedRectangleBorder;
      expect(forma.borderRadius, BorderRadius.circular(12));
      final card = tema.cardTheme.shape! as RoundedRectangleBorder;
      expect(card.borderRadius, BorderRadius.circular(16));
    });

    test('alvo de toque padded (48dp) no tema', () {
      expect(tema.materialTapTargetSize, MaterialTapTargetSize.padded);
    });
  });

  group('1.5/1.6 contraste WCAG a partir dos tokens reais', () {
    // Texto: >= 4.5:1 (WCAG AA, texto normal). Origem do limiar: MASTER.md / TAREFA 1.
    final texto = <String, (Color, Color)>{
      'onSurface/surface': (cs.onSurface, cs.surface),
      'onSurface/background': (cs.onSurface, fundo),
      'onSurface/surfaceHigh': (cs.onSurface, t.surfaceHigh),
      'muted/surface': (t.onSurfaceMuted, cs.surface),
      'muted/surfaceHigh': (t.onSurfaceMuted, t.surfaceHigh),
      'muted/background': (t.onSurfaceMuted, fundo),
      'primary/surface': (cs.primary, cs.surface),
      'primary/background': (cs.primary, fundo),
      'primary/surfaceHigh': (cs.primary, t.surfaceHigh),
      'onPrimary/primary': (cs.onPrimary, cs.primary),
      'error/surface': (cs.error, cs.surface),
      'error/surfaceHigh': (cs.error, t.surfaceHigh),
      'error/background': (cs.error, fundo),
      'onError/error': (cs.onError, cs.error),
      'success/surface': (t.success, cs.surface),
      'warning/surface': (t.warning, cs.surface),
      'info/surface': (t.info, cs.surface),
      'neutral/surface': (t.neutral, cs.surface),
      'success/surfaceHigh': (t.success, t.surfaceHigh),
      'warning/surfaceHigh': (t.warning, t.surfaceHigh),
      'info/surfaceHigh': (t.info, t.surfaceHigh),
      'neutral/surfaceHigh': (t.neutral, t.surfaceHigh),
      // containers usados por chip selecionado, indicador da NavigationBar e SegmentedButton (R7)
      'onSecondaryContainer/secondaryContainer': (cs.onSecondaryContainer, cs.secondaryContainer),
      'onPrimaryContainer/primaryContainer': (cs.onPrimaryContainer, cs.primaryContainer),
      'primary/primaryContainer': (cs.primary, cs.primaryContainer),
      'onErrorContainer/errorContainer': (cs.onErrorContainer, cs.errorContainer),
      'error/errorContainer': (cs.error, cs.errorContainer),
      'onSurfaceVariant/surface': (cs.onSurfaceVariant, cs.surface),
      'onSurface/surfaceContainerHighest': (cs.onSurface, cs.surfaceContainerHighest),
      'outline como texto desabilitado/background': (cs.outline, fundo),
    };
    for (final e in texto.entries) {
      test('texto ${e.key} >= 4.5', () {
        final r = contraste(e.value.$1, e.value.$2);
        expect(r, greaterThanOrEqualTo(4.5), reason: '${e.key} = ${r.toStringAsFixed(2)}');
      });
    }

    // Borda que carrega informação: >= 3:1 (WCAG 1.4.11).
    final bordas = <String, (Color, Color)>{
      'outline/surface': (cs.outline, cs.surface),
      'outline/surfaceHigh': (cs.outline, t.surfaceHigh),
      'outline/background': (cs.outline, fundo),
    };
    for (final e in bordas.entries) {
      test('borda ${e.key} >= 3.0', () {
        final r = contraste(e.value.$1, e.value.$2);
        expect(r, greaterThanOrEqualTo(3.0), reason: '${e.key} = ${r.toStringAsFixed(2)}');
      });
    }

    test('os valores batem com os medidos pelo analista (sanidade da fórmula)', () {
      expect(contraste(cs.onSurface, cs.surface), closeTo(16.74, 0.05));
      expect(contraste(cs.outline, t.surfaceHigh), closeTo(4.07, 0.05));
      expect(contraste(cs.onPrimary, cs.primary), closeTo(8.32, 0.05));
    });
  });
}
