import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_palette.dart';

class AppTypography {
  static TextTheme get lightTheme => GoogleFonts.robotoTextTheme().apply(
        bodyColor: AppPalette.textLightPrimary,
        displayColor: AppPalette.textLightPrimary,
      );

  static TextTheme get darkTheme => GoogleFonts.robotoTextTheme().apply(
        bodyColor: AppPalette.textDarkPrimary,
        displayColor: AppPalette.textDarkPrimary,
      );
}