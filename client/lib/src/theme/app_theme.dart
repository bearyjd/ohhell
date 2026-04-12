import 'package:flutter/material.dart';

abstract final class AppColors {
  static const feltGreen = Color(0xFF1B5E20);
  static const cardSurface = Color(0xFFFFFDE7);
  static const cardBack = Color(0xFF1565C0);
  static const suitRed = Color(0xFFD32F2F);
  static const suitBlack = Color(0xFF212121);
  static const gold = Color(0xFFFFD700);
  static const error = Color(0xFFE53935);
  static const textOnDark = Colors.white;
}

abstract final class AppTheme {
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: AppColors.gold,
        onPrimary: AppColors.suitBlack,
        secondary: AppColors.feltGreen,
        onSecondary: AppColors.textOnDark,
        surface: const Color(0xFF2E7D32),
        onSurface: AppColors.textOnDark,
        error: AppColors.error,
        onError: AppColors.textOnDark,
      ),
      scaffoldBackgroundColor: AppColors.feltGreen,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF154A19),
        foregroundColor: AppColors.gold,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.suitBlack,
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2E7D32),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppColors.gold.withAlpha(128),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.gold, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.gold),
        hintStyle: TextStyle(
          color: AppColors.textOnDark.withAlpha(128),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.gold,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: AppColors.gold,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: TextStyle(
          color: AppColors.textOnDark,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: AppColors.textOnDark,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: AppColors.textOnDark),
        bodyMedium: TextStyle(color: AppColors.textOnDark),
        labelLarge: TextStyle(
          color: AppColors.suitBlack,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
