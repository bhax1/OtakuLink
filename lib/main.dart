import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:otakulink/theme.dart';
import 'package:safe_device/safe_device.dart'; 
import 'package:otakulink/authenticator.dart';
import 'package:otakulink/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 2. SECURITY PRE-CHECK
  bool isSafe = await _performSecurityCheck();

  if (!isSafe) {
    runApp(const SecurityLockdownApp());
    return;
  }

  try {
    await _initServices();
  } catch (e) {
    debugPrint("CRITICAL INIT ERROR: $e");
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ProviderScope(child: MyApp()));
}

/// Checks if the device is compromised.
Future<bool> _performSecurityCheck() async {
  try {
    // Check if device is Jailbroken or Rooted
    bool isJailbroken = await SafeDevice.isJailBroken;
    
    // bool isRealDevice = await SafeDevice.isRealDevice; // Optional emulator check

    if (isJailbroken) {
      debugPrint("SECURITY ALERT: Device is rooted/jailbroken.");
      return false; 
    }
    return true;
  } catch (e) {
    // Fail safe: Allow app to run if check errors out, but log it.
    debugPrint("Security check failed with error: $e");
    return true; 
  }
}

Future<void> _initServices() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  await _openEncryptedBox();
}

Future<void> _openEncryptedBox() async {
  const secureStorage = FlutterSecureStorage();
  const keyStorageKey = 'hiveKey';
  const boxName = 'userCache';

  try {
    String? keyString = await secureStorage.read(key: keyStorageKey);
    List<int> encryptionKey;

    if (keyString == null) {
      encryptionKey = Hive.generateSecureKey();
      await secureStorage.write(
        key: keyStorageKey,
        value: base64UrlEncode(encryptionKey),
      );
    } else {
      encryptionKey = base64Url.decode(keyString);
    }

    await Hive.openBox(
      boxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
  } catch (e) {
    debugPrint("Hive Encryption Error: $e. RESETTING BOX.");
    await Hive.deleteBoxFromDisk(boxName);
    
    final newKey = Hive.generateSecureKey();
    await secureStorage.write(
      key: keyStorageKey,
      value: base64UrlEncode(newKey),
    );
    
    await Hive.openBox(
      boxName,
      encryptionCipher: HiveAesCipher(newKey),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OtakuLink',
      
      // 3. UPDATE: Use the new AppTheme class
      theme: AppTheme.lightTheme, 
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light, 
      
      home: const Authenticator(),
    );
  }
}

// 🛑 The "You are blocked" screen
class SecurityLockdownApp extends StatelessWidget {
  const SecurityLockdownApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // We keep this hardcoded to black/red to emphasize the warning
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security, color: Colors.red, size: 80),
                const SizedBox(height: 20),
                const Text(
                  "Security Risk Detected",
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  "This device appears to be rooted or jailbroken. For your security, OtakuLink cannot run on this device.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white
                  ),
                  onPressed: () => exit(0),
                  child: const Text("Exit App"),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}