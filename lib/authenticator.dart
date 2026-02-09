import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:otakulink/main/home_screen.dart';
import 'main/login_screen.dart';

class Authenticator extends StatefulWidget {
  const Authenticator({super.key});

  @override
  _AuthenticatorState createState() => _AuthenticatorState();
}

class _AuthenticatorState extends State<Authenticator> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Connectivity _connectivity = Connectivity();
  
  // 1. Declare a variable to hold the stream
  late Stream<User?> _authStream; 
  
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _wasOnline = true; 

  @override
  void initState() {
    super.initState();
    // 2. Initialize the stream ONCE here
    _authStream = _auth.userChanges(); 
    
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectivityStatus);
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  // Helper: Real Internet Check
  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  void _updateConnectivityStatus(List<ConnectivityResult> results) async {
    bool isConnectedToNetwork = !results.contains(ConnectivityResult.none);
    
    // 1. If we completely lost connection to router/tower
    if (!isConnectedToNetwork) {
       _handleOffline();
       return;
    }

    // 2. If we are connected to a router, check if it actually has Data
    bool hasRealInternet = await _hasInternetConnection();

    // Check if the widget is still in the tree after the await
    if (!mounted) return;

    if (hasRealInternet) {
      _handleOnline();
    } else {
      // REQUIREMENT: "If connected to internet but no data... do nothing"
      // We do NOT show "Back Online", but we also don't spam "Offline" 
      // if we were already offline.
      if (_wasOnline) {
        _handleOffline(); // Transitioned from Good -> Bad Data
      }
    }
  }

  void _handleOffline() {
    if (_wasOnline) {
      setState(() => _wasOnline = false);
      _showSnackBar("You're not connected", isError: true);
    }
  }

  void _handleOnline() {
    if (!_wasOnline) {
      setState(() => _wasOnline = true);
      _showSnackBar("You're back online!", isError: false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    // Only show if the widget is currently visible
    if (!mounted) return;
    
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(isError ? Icons.wifi_off : Icons.wifi, color: Colors.white),
          const SizedBox(width: 10),
          Text(message),
        ],
      ),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating, // Makes it float above bottom nav bars
    );

    ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Remove old messages
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    // SECURITY IMPROVEMENT: We removed the blocking "No Internet" Scaffold.
    // The app now allows the user to browse cached content even if offline.
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<User?>(
        stream: _authStream, // 3. Use the stable variable, not the function call
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Authentication Error'));
          } else if (snapshot.hasData) {
            User? user = snapshot.data;
            if (user != null && user.emailVerified) {
              return const HomeScreen();
            } else {
              return const VerifyEmailScreen();
            }
          }
          // Make sure LoginScreen is const so it doesn't rebuild unnecessarily
          return const LoginScreen(); 
        },
      ),
    );
  }
}

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify Email")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Please verify your email address."),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async => await FirebaseAuth.instance.currentUser?.reload(),
              child: const Text("I have verified my email"),
            ),
            TextButton(
              onPressed: () async => await FirebaseAuth.instance.signOut(),
              child: const Text("Sign Out"),
            )
          ],
        ),
      ),
    );
  }
}