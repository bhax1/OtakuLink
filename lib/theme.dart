import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Optional: for better typography

// 1. Constants & Colors
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF33415C);
  static const Color accent = Colors.orangeAccent;

  // Neutral Colors for Backgrounds/Text
  static const Color textLight = Color(0xFF1D1D1D);
  static const Color textDark = Color(0xFFE0E0E0);
  static const Color backgroundLight = Color(0xFFF5F7FA);
  static const Color backgroundDark = Color(0xFF121212); // Standard Dark Mode BG
}

// 2. The Theme Manager
class AppTheme {
  // --- Typography ---
  // Define once to share across both themes.
  static TextTheme _buildTextTheme(TextTheme base, Color color) {
    return base.copyWith(
      displayLarge: GoogleFonts.roboto(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 32,
      ),
      displayMedium: GoogleFonts.roboto(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 28,
      ),
      titleLarge: GoogleFonts.roboto(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: 22,
      ),
      bodyLarge: GoogleFonts.roboto(
        color: color,
        fontSize: 16,
      ),
      bodyMedium: GoogleFonts.roboto(
        color: color,
        fontSize: 14,
      ),
    );
  }

  // --- Light Theme ---
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // Color Scheme
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: Colors.black,
      surface: Colors.white,
      onSurface: AppColors.textLight,
      error: Colors.redAccent,
    ),

    scaffoldBackgroundColor: AppColors.backgroundLight,

    // Text Theme
    textTheme: _buildTextTheme(
      ThemeData.light().textTheme,
      AppColors.textLight,
    ),

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),

    // Inputs (TextFields)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 2,
        ),
      ),
    ),

    // Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
  );

  // --- Dark Theme ---
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // Color Scheme
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: Colors.black,
      surface: Color(0xFF1E1E1E), // Slightly lighter than background
      onSurface: AppColors.textDark,
      error: Colors.redAccent,
    ),

    scaffoldBackgroundColor: AppColors.backgroundDark,

    // Text Theme
    textTheme: _buildTextTheme(
      ThemeData.dark().textTheme,
      AppColors.textDark,
    ),

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.backgroundDark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),

    // Inputs (TextFields)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: AppColors.accent,
          width: 2,
        ),
      ),
    ),

    // Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
  );
}
