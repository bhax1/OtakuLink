import 'package:flutter/material.dart';

// Light theme (original theme)
final ThemeData lightTheme = ThemeData(
  primaryColor: Color(0xFF33415C),
  hintColor: Colors.orangeAccent,
  scaffoldBackgroundColor: Colors.white,
  textTheme: TextTheme(
    bodyLarge: TextStyle(color: Colors.black87),
    bodyMedium: TextStyle(color: Colors.black87),
    titleLarge: TextStyle(color: Colors.black87, fontSize: 24, fontWeight: FontWeight.bold),
  ),
  cardColor: Colors.grey.shade200,
  visualDensity: VisualDensity.adaptivePlatformDensity,
);

// Dark theme
final ThemeData darkTheme = ThemeData(
  primaryColor: Color(0xFF33415C),
  hintColor: Colors.orangeAccent,
  scaffoldBackgroundColor: Colors.black87,
  textTheme: TextTheme(
    bodyLarge: TextStyle(color: Colors.white70),
    bodyMedium: TextStyle(color: Colors.white70),
    titleLarge: TextStyle(color: Colors.white70, fontSize: 24, fontWeight: FontWeight.bold),
  ),
  cardColor: Colors.grey.shade800,
  visualDensity: VisualDensity.adaptivePlatformDensity,
);
