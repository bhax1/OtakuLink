import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:otakulink/pages/home_screen.dart';
import 'pages/login_screen.dart';

class Authenticator extends StatefulWidget {
  const Authenticator({super.key});

  @override
  _AuthenticatorState createState() => _AuthenticatorState();
}

class _AuthenticatorState extends State<Authenticator> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  bool _isConnected = true;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_updateConnectivityStatus);
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  // Check initial connectivity state when the app starts
  Future<void> _checkInitialConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _updateConnectivityStatus(result);
  }

  // Update connectivity status based on network changes
  void _updateConnectivityStatus(ConnectivityResult result) {
    setState(() {
      final wasConnected = _isConnected;
      _isConnected = result != ConnectivityResult.none;

      if (_isConnected && !wasConnected) {
        _statusMessage = "Connection restored";
        Future.delayed(const Duration(seconds: 2), () {
          setState(() {
            _statusMessage = '';
          });
        });
      }
    });
  }

  // Retry network connection when button is pressed
  void _retryConnection() async {
    final result = await _connectivity.checkConnectivity();
    setState(() {
      if (result == ConnectivityResult.none) {
        _statusMessage = "Failed to connect";
      } else {
        _statusMessage = "";
        _isConnected = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Handle no internet connection
    if (!_isConnected) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, size: 100, color: Colors.grey),
              const SizedBox(height: 20),
              const Text('No Internet Connection',
                  style: TextStyle(fontSize: 18)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _retryConnection,
                child: const Text('Retry'),
              ),
              const SizedBox(height: 10),
              Text(_statusMessage,
                  style: const TextStyle(color: Colors.red, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    // Show connection message if it changed
    if (_statusMessage.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_statusMessage),
              duration: const Duration(seconds: 2)),
        );
      });
    }

    // Proceed with authentication logic when connected
    return Scaffold(
        body: StreamBuilder<User?>(
      stream: _auth.authStateChanges(), // Listen to auth state changes
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return const Center(child: Text('Something went wrong!'));
        } else if (snapshot.hasData) {
          // If user is logged in, check if the email is verified
          User? user = snapshot.data;
          if (user != null && user.emailVerified) {
            return const HomeScreen(); // User can go to Page1
          } else {
            // If email is not verified, navigate to LoginScreen
            return const LoginScreen();
          }
        } else {
          // If no user is logged in, navigate to LoginScreen
          return const LoginScreen();
        }
      },
    ));
  }
}
