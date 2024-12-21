import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:hive_flutter/hive_flutter.dart';
import 'package:otakulink/authenticator.dart';
import 'package:otakulink/firebase_options.dart';

final Color primaryColor = Color(0xFF33415C);
final Color accentColor = Colors.orangeAccent;
final Color backgroundColor = Colors.white;
final Color secondaryColor = Colors.grey.shade200;
final Color textColor = Colors.black87;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('userCache');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: MyApp()));
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
        cardColor: secondaryColor,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const Authenticator(),
    );
  }
}
