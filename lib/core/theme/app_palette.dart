import 'package:flutter/material.dart';

class AppPalette {
  AppPalette._(); // Private constructor

  // Brand Identity
  static const Color primary = Color(0xFF33415C);
  static const Color accent = Colors.orangeAccent;

  // New: Lighter primary for Dark Mode visibility
  static const Color primaryDarkDisplay = Color(0xFF283244);
  static const Color accentDarkDisplay = Color(0xFFFFA94D);

  // Backgrounds
  static const Color backgroundLight = Color(0xFFF5F7FA);
  
  // Soft Dark Mode (Not pitch black)
  static const Color backgroundDark = Color(0xFF242933); 
  static const Color surfaceDark = Color(0xFF343B48);   

  // Text
  static const Color textLightPrimary = Color(0xFF1D1D1D);
  static const Color textDarkPrimary = Color(0xFFF0F0F0); 
  
  // Semantic (Validation)
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);
}