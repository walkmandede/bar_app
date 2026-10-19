// core/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg = Color(0xFFFCFCFD); // page background, almost white
  static const muted = Color(0xFFF3F3F5); // soft grey for chips, placeholders, selected tiles
  static const surface = Colors.white;
  static const border = Color(0xFFE9E9EC);
  static const text = Color(0xFF1A1A1A);
  static const textSoft = Color(0xFF8A8A90);

  static const primary = Color(0xFFE8553D);
  static const primarySoft = Color(0xFFFDEEEA);
  static const success = Color(0xFF1E9E5A);
  static const successSoft = Color(0xFFE6F6EE);
  static const danger = Color(0xFFD93B2B);
  static const dangerSoft = Color(0xFFFDECEA);
  static const info = Color(0xFF4B5FD6);
  static const infoSoft = Color(0xFFEBEDFC);
}

class AppTheme {
  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          surface: AppColors.surface,
          onSurface: AppColors.text,
          error: AppColors.danger,
        );

    final textTheme = GoogleFonts.nunitoSansTextTheme(
      ThemeData(brightness: Brightness.light).textTheme,
    ).apply(bodyColor: AppColors.text, displayColor: AppColors.text);

    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.bg,
      dividerColor: AppColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.primary),
        errorBorder: border(AppColors.danger),
        focusedErrorBorder: border(AppColors.danger),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primarySoft,
      ),
    );
  }
}
