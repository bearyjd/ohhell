import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const background = Color(0xFF1A1040);
  static const surface = Color(0xFF251857);
  static const appBar = Color(0xFF120D30);
  static const amber = Color(0xFFFBBF24);
  static const onPrimary = Color(0xFF1C1917);
  static const cardSurface = Color(0xFFFFFFFF);
  static const suitRed = Color(0xFFEF4444);
  static const suitBlack = Color(0xFF1E293B);
  static const success = Color(0xFF34D399);
  static const error = Color(0xFFF87171);
  static const textOnDark = Colors.white;

  // Backward-compatible aliases
  static const gold = amber;
  static const feltGreen = background;
  static const cardBack = Color(0xFF251857);
}

abstract final class AppTheme {
  static ThemeData dark() {
    final baseTextTheme = GoogleFonts.nunitoTextTheme(
      const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.amber,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: AppColors.amber,
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
          color: AppColors.onPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: AppColors.amber,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.success,
        onSecondary: AppColors.onPrimary,
        surface: AppColors.surface,
        onSurface: AppColors.textOnDark,
        error: AppColors.error,
        onError: AppColors.textOnDark,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.appBar,
        foregroundColor: AppColors.amber,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.amber,
          foregroundColor: AppColors.onPrimary,
          textStyle: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.amber,
          side: const BorderSide(color: AppColors.amber),
          textStyle: GoogleFonts.nunito(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.amber),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: AppColors.amber.withAlpha(128),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.amber, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.amber),
        hintStyle: TextStyle(
          color: AppColors.textOnDark.withAlpha(128),
        ),
      ),
      textTheme: baseTextTheme,
    );
  }
}
