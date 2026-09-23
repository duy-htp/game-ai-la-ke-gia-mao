import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get dark {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.indigo,
          brightness: Brightness.dark,
          surface: AppColors.navy900,
          error: AppColors.impostorRed,
        ).copyWith(
          primary: AppColors.indigo,
          secondary: AppColors.gold,
          surface: AppColors.navy900,
          onSurface: AppColors.textPrimary,
        );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.navy950,
      useMaterial3: true,
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 38,
          fontWeight: FontWeight.w900,
          height: 1.02,
          letterSpacing: -1.2,
        ),
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
        bodyMedium: TextStyle(color: AppColors.textMuted, height: 1.4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(58),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.navy800,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
