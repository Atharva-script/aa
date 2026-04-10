import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Cyber Owl App Theme
/// Continuous ThemeData using Interpolation
class AppTheme {
  // ============= PITCH DARK THEME =============
  static final ThemeData _darkTheme = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.blackBackground,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryPurple,
      secondary: AppColors.primaryBlue,
      surface: AppColors.blackSurface,
      error: Color(0xFFF87171),
      onSurface: AppColors.blackText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.blackBackground,
      foregroundColor: AppColors.blackText,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: AppColors.blackSurface,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0x33FFFFFF)),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.blackText),
      bodyMedium: TextStyle(color: Color(0xFF9CA3AF)),
    ),
    // Add other theme data as needed, kept minimal for interpolation base
  );

  // ============= PITCH LIGHT THEME =============
  static final ThemeData _lightTheme = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.whiteBackground,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryPurple,
      secondary: AppColors.primaryBlue,
      surface: AppColors.whiteSurface,
      error: Color(0xFFDC2626),
      onSurface: AppColors.whiteText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.whiteBackground,
      foregroundColor: AppColors.whiteText,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: AppColors.whiteSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0x1A000000)),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.whiteText),
      bodyMedium: TextStyle(color: Color(0xFF4A5568)),
    ),
  );

  // ============= INTERPOLATION =============
  static ThemeData getTheme(double t) {
    return ThemeData.lerp(_darkTheme, _lightTheme, t);
  }
}
