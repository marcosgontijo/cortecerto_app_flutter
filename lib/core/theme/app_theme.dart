import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,

      colorScheme: const ColorScheme(
        brightness: Brightness.dark, // 🔥 CORREÇÃO AQUI
        primary: AppColors.primary,
        onPrimary: AppColors.textLight,
        secondary: AppColors.secondary,
        onSecondary: Colors.black,
        error: Colors.red,
        onError: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textLight,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
        centerTitle: true,
        elevation: 4,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.button,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),

      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: AppColors.secondary,
            width: 2,
          ),
        ),
        labelStyle: TextStyle(color: AppColors.textLight),
      ),

      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.textLight),
        bodyMedium: TextStyle(color: AppColors.textLight),
        titleLarge: TextStyle(
          color: AppColors.textLight, // 🔥 corrigido
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
