import 'package:flutter/material.dart';

/// Paleta do design system (`design-system/cortecerto/MASTER.md`, tema escuro).
/// As telas não usam estas constantes direto: leem `Theme.of(context).colorScheme`
/// ou a extensão [AppTokens]. Só o tema e os tokens importam este arquivo.
class AppColors {
  AppColors._();

  // Superfícies e texto
  static const background = Color(0xFF0C0A09);
  static const surface = Color(0xFF1C1917);
  static const surfaceHigh = Color(0xFF292524);
  static const onSurface = Color(0xFFFAFAF9);
  static const onSurfaceMuted = Color(0xFFA8A29E);

  // Marca
  static const primary = Color(0xFFD4A017);
  static const onPrimary = Color(0xFF0C0A09);

  /// Fundo dourado escuro de itens selecionados (chip, indicador da barra, segmento).
  static const primaryContainer = Color(0xFF4A3A0C);
  static const onPrimaryContainer = Color(0xFFFAFAF9);

  // Bordas
  static const outline = Color(0xFF8A837E);
  static const divider = Color(0xFF44403C);

  // Erro
  static const error = Color(0xFFF87171);
  static const onError = Color(0xFF0C0A09);
  static const errorContainer = Color(0xFF450A0A);
  static const onErrorContainer = Color(0xFFFECACA);

  // Status
  static const success = Color(0xFF4ADE80);
  static const warning = Color(0xFFFBBF24);
  static const info = Color(0xFF60A5FA);
  static const neutral = Color(0xFFA8A29E);

  static const shadow = Color(0xFF000000);
}
