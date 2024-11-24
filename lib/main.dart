import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:otakulink/authenticator.dart';
import 'package:otakulink/firebase_options.dart';

final Color primaryColor = Color(0xFF33415C);  // Main color
final Color accentColor = Colors.orangeAccent;  // Accent color
final Color backgroundColor = Colors.white;  // Background color
final Color secondaryColor = Colors.grey.shade200;  // Light grey for sections
final Color textColor = Colors.black87;  // Text color

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: primaryColor,
        hintColor: accentColor,
        scaffoldBackgroundColor: backgroundColor,
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: textColor),
          bodyMedium: TextStyle(color: textColor),
          titleLarge: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        cardColor: secondaryColor,  // Set card background color
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const Authenticator(),
    );
  }
}
