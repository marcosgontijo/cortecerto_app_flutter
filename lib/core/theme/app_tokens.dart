import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tokens do design system que o `ColorScheme` não cobre: cores de status, texto
/// secundário, superfície elevada, espaçamentos e raios.
///
/// Uso: `AppTokens.of(context).success`, `AppTokens.of(context).md`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.success,
    required this.warning,
    required this.info,
    required this.neutral,
    required this.onSurfaceMuted,
    required this.surfaceHigh,
    required this.divider,
    this.xs = 4,
    this.sm = 8,
    this.md = 16,
    this.lg = 24,
    this.xl = 32,
    this.xxl = 48,
    this.raioCampo = 12,
    this.raioCard = 16,
    this.raioChip = 999,
    this.raioSheet = 24,
  });

  /// Tokens do tema escuro (o único desta fase).
  static const escuro = AppTokens(
    success: AppColors.success,
    warning: AppColors.warning,
    info: AppColors.info,
    neutral: AppColors.neutral,
    onSurfaceMuted: AppColors.onSurfaceMuted,
    surfaceHigh: AppColors.surfaceHigh,
    divider: AppColors.divider,
  );

  /// Tokens do tema atual (cai no escuro se o tema não registrou a extensão).
  static AppTokens of(BuildContext context) =>
      Theme.of(context).extension<AppTokens>() ?? escuro;

  final Color success;
  final Color warning;
  final Color info;
  final Color neutral;
  final Color onSurfaceMuted;
  final Color surfaceHigh;
  final Color divider;

  // Espaçamentos (escala 4/8)
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;

  // Raios
  final double raioCampo;
  final double raioCard;
  final double raioChip;
  final double raioSheet;

  @override
  AppTokens copyWith({
    Color? success,
    Color? warning,
    Color? info,
    Color? neutral,
    Color? onSurfaceMuted,
    Color? surfaceHigh,
    Color? divider,
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xxl,
    double? raioCampo,
    double? raioCard,
    double? raioChip,
    double? raioSheet,
  }) {
    return AppTokens(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      neutral: neutral ?? this.neutral,
      onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      divider: divider ?? this.divider,
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
      raioCampo: raioCampo ?? this.raioCampo,
      raioCard: raioCard ?? this.raioCard,
      raioChip: raioChip ?? this.raioChip,
      raioSheet: raioSheet ?? this.raioSheet,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    double d(double a, double b) => lerpDouble(a, b, t)!;
    return AppTokens(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      onSurfaceMuted: Color.lerp(onSurfaceMuted, other.onSurfaceMuted, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      xs: d(xs, other.xs),
      sm: d(sm, other.sm),
      md: d(md, other.md),
      lg: d(lg, other.lg),
      xl: d(xl, other.xl),
      xxl: d(xxl, other.xxl),
      raioCampo: d(raioCampo, other.raioCampo),
      raioCard: d(raioCard, other.raioCard),
      raioChip: d(raioChip, other.raioChip),
      raioSheet: d(raioSheet, other.raioSheet),
    );
  }
}
