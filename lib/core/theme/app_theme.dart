import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

/// Tema do app (design system em `design-system/cortecerto/MASTER.md`).
/// Só existe o tema escuro nesta fase; os tokens ficam em [AppColors] e [AppTokens]
/// para permitir um tema claro depois.
class AppTheme {
  AppTheme._();

  /// Todos os papéis do esquema são definidos, para que chips selecionados, a
  /// NavigationBar e o SegmentedButton não caiam em cores padrão com contraste ruim.
  static const ColorScheme colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.onPrimaryContainer,
    secondary: AppColors.primary,
    onSecondary: AppColors.onPrimary,
    secondaryContainer: AppColors.primaryContainer,
    onSecondaryContainer: AppColors.onPrimaryContainer,
    tertiary: AppColors.info,
    onTertiary: AppColors.onPrimary,
    tertiaryContainer: AppColors.surfaceHigh,
    onTertiaryContainer: AppColors.onSurface,
    error: AppColors.error,
    onError: AppColors.onError,
    errorContainer: AppColors.errorContainer,
    onErrorContainer: AppColors.onErrorContainer,
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
    onSurfaceVariant: AppColors.onSurfaceMuted,
    surfaceDim: AppColors.background,
    surfaceBright: AppColors.surfaceHigh,
    surfaceContainerLowest: AppColors.background,
    surfaceContainerLow: AppColors.surface,
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.surfaceHigh,
    surfaceContainerHighest: AppColors.surfaceHigh,
    outline: AppColors.outline,
    outlineVariant: AppColors.divider,
    shadow: AppColors.shadow,
    scrim: AppColors.shadow,
    inverseSurface: AppColors.onSurface,
    onInverseSurface: AppColors.surface,
    inversePrimary: AppColors.primaryContainer,
    // Sem tinta de elevação: as superfícies ficam exatamente nas cores do MASTER.
    surfaceTint: Colors.transparent,
  );

  /// Escala tipográfica do MASTER (nenhum estilo abaixo de 12).
  static const TextTheme _escala = TextTheme(
    displayLarge: TextStyle(fontSize: 48, fontWeight: FontWeight.w700),
    displayMedium: TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
    displaySmall: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
    headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
    headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.45),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4),
    labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
  );

  static ThemeData get darkTheme {
    const cs = colorScheme;
    const t = AppTokens.escuro;
    final texto = _escala.apply(bodyColor: cs.onSurface, displayColor: cs.onSurface);
    final raioCampo = BorderRadius.circular(t.raioCampo);
    final raioCard = BorderRadius.circular(t.raioCard);

    OutlineInputBorder borda(Color cor, [double largura = 1]) => OutlineInputBorder(
          borderRadius: raioCampo,
          borderSide: BorderSide(color: cor, width: largura),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: cs,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      dividerColor: AppColors.divider,
      textTheme: texto,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: const [t],
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: texto.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        // Cores padrão do M3 (primary/onPrimary); o tonal usa secondaryContainer.
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: EdgeInsets.symmetric(horizontal: t.lg),
          shape: RoundedRectangleBorder(borderRadius: raioCampo),
          textStyle: texto.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          minimumSize: const Size(64, 48),
          padding: EdgeInsets.symmetric(horizontal: t.md),
          side: BorderSide(color: cs.outline),
          shape: RoundedRectangleBorder(borderRadius: raioCampo),
          textStyle: texto.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          minimumSize: const Size(48, 48),
          padding: EdgeInsets.symmetric(horizontal: t.md),
          shape: RoundedRectangleBorder(borderRadius: raioCampo),
          textStyle: texto.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: t.md, vertical: t.md),
        border: borda(cs.outline),
        enabledBorder: borda(cs.outline),
        focusedBorder: borda(cs.primary, 2),
        errorBorder: borda(cs.error),
        focusedErrorBorder: borda(cs.error, 2),
        disabledBorder: borda(AppColors.divider),
        labelStyle: texto.bodyLarge?.copyWith(color: t.onSurfaceMuted),
        floatingLabelStyle: texto.bodyLarge?.copyWith(color: cs.primary),
        hintStyle: texto.bodyLarge?.copyWith(color: t.onSurfaceMuted),
        helperStyle: texto.bodySmall?.copyWith(color: t.onSurfaceMuted),
        errorStyle: texto.bodySmall?.copyWith(color: cs.error),
        errorMaxLines: 3,
        prefixIconColor: t.onSurfaceMuted,
        suffixIconColor: t.onSurfaceMuted,
      ),
      cardTheme: CardThemeData(
        color: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: raioCard,
          side: const BorderSide(color: AppColors.divider),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.surfaceHigh,
        selectedColor: cs.secondaryContainer,
        disabledColor: cs.surface,
        checkmarkColor: cs.onSecondaryContainer,
        labelStyle: texto.labelMedium?.copyWith(color: cs.onSurface),
        secondaryLabelStyle: texto.labelMedium?.copyWith(color: cs.onSecondaryContainer),
        side: BorderSide(color: cs.outline),
        shape: const StadiumBorder(),
        padding: EdgeInsets.symmetric(horizontal: t.sm, vertical: t.xs),
        iconTheme: IconThemeData(color: cs.onSurface, size: 18),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          textStyle: WidgetStatePropertyAll(texto.labelMedium),
          side: WidgetStatePropertyAll(BorderSide(color: cs.outline)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? cs.secondaryContainer : cs.surface,
          ),
          foregroundColor: WidgetStatePropertyAll(cs.onSurface),
          iconColor: WidgetStatePropertyAll(cs.onSurface),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        indicatorColor: cs.secondaryContainer,
        elevation: 0,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => texto.labelMedium?.copyWith(
            color: s.contains(WidgetState.selected) ? cs.onSurface : t.onSurfaceMuted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected) ? cs.onSecondaryContainer : t.onSurfaceMuted,
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: cs.primary,
        unselectedLabelColor: t.onSurfaceMuted,
        indicatorColor: cs.primary,
        dividerColor: AppColors.divider,
        labelStyle: texto.labelLarge,
        unselectedLabelStyle: texto.labelLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.surfaceHigh,
        contentTextStyle: texto.bodyMedium?.copyWith(color: cs.onSurface),
        actionTextColor: cs.primary,
        shape: RoundedRectangleBorder(borderRadius: raioCampo),
        elevation: 2,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.raioSheet)),
        titleTextStyle: texto.titleLarge,
        contentTextStyle: texto.bodyMedium?.copyWith(color: cs.onSurface),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: cs.outline,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(t.raioSheet)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: raioCard),
        extendedTextStyle: texto.labelLarge,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: t.onSurfaceMuted,
        textColor: cs.onSurface,
        minVerticalPadding: t.sm,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? cs.primary : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(cs.onPrimary),
        side: BorderSide(color: cs.outline, width: 2),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: cs.primary),
      dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1),
      iconTheme: IconThemeData(color: cs.onSurface, size: 24),
    );
  }
}
