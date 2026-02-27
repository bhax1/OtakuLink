import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for SystemUiOverlayStyle
import 'app_palette.dart';
import 'app_typography.dart';
import 'component_styles.dart';

class AppTheme {
  // --- Light Theme ---
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppPalette.backgroundLight,
    colorScheme: const ColorScheme.light(
      primary: AppPalette.primary,
      secondary: AppPalette.accent,
      surface: Colors.white,
      error: AppPalette.error,
    ),
    textTheme: AppTypography.lightTheme,
    inputDecorationTheme: ComponentStyles.inputDecoration(false),
    elevatedButtonTheme: ComponentStyles.elevatedButton(false),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppPalette.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle(
        systemNavigationBarColor: AppPalette.backgroundLight,
      ),
    ),
  );

  // --- Dark Theme ---
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppPalette.backgroundDark,
    colorScheme: const ColorScheme.dark(
      primary: AppPalette.primaryDarkDisplay,
      onPrimary: Colors.white,
      secondary: AppPalette.accentDarkDisplay,
      surface: AppPalette.surfaceDark,
      error: AppPalette.error,
    ),
    textTheme: AppTypography.darkTheme,
    inputDecorationTheme: ComponentStyles.inputDecoration(true),
    elevatedButtonTheme: ComponentStyles.elevatedButton(true),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppPalette.backgroundDark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle(
        systemNavigationBarColor: AppPalette.backgroundDark,
      ),
    ),
  );
}
