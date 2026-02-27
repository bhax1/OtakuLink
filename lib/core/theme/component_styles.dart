import 'package:flutter/material.dart';
import 'app_palette.dart';

class ComponentStyles {
  // Input Decoration (TextFields)
  static InputDecorationTheme inputDecoration(bool isDark) {
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey[400]!;
    final fillColor = isDark ? AppPalette.surfaceDark : Colors.white;
    final labelColor = isDark ? Colors.grey[400] : Colors.grey[700];

    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      labelStyle: TextStyle(
        color: labelColor,
        fontSize: 16,
      ),
      floatingLabelStyle: TextStyle(
        color: AppPalette.accent,
        fontSize: 16,
      ),
      border: _outline(borderColor),
      enabledBorder: _outline(borderColor),
      focusedBorder: _outline(AppPalette.accent, width: 2),
      errorBorder: _outline(AppPalette.error),
    );
  }

  static OutlineInputBorder _outline(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  // Elevated Button Style
  static ElevatedButtonThemeData elevatedButton(bool isDark) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? AppPalette.accent : AppPalette.primary,
        foregroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
