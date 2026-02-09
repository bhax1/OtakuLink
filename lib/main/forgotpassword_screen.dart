import 'dart:async'; // For TimeoutException
import 'dart:io';   // For InternetAddress.lookup

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FocusNode _emailFocusNode = FocusNode();
  bool _isLoading = false;

  // 1. IMPROVED SNACKBAR: Matches your new Login design
  void _showSnackbar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // 2. HARDENED RESET LOGIC
  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    _emailFocusNode.unfocus();

    // A. CONNECTION PRE-CHECK
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        throw SocketException("No internet");
      }
    } on SocketException catch (_) {
      _showSnackbar("No internet connection.", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // B. TIMEOUT PROTECTION
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: _emailController.text.trim())
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      
      // Success case
      _showSnackbar(
        "If an account exists, a reset link has been sent.", 
        isError: false,
      );
      
      // Optional: Clear the field so they can't spam
      _emailController.clear(); 

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      // C. SECURITY: PREVENT ENUMERATION
      // If the email is valid format but user not found, 
      // we LIE and say "Success" so hackers can't guess valid emails.
      if (e.code == 'user-not-found') {
        _showSnackbar(
          "If an account exists, a reset link has been sent.", 
          isError: false,
        );
      } else if (e.code == 'invalid-email') {
        _showSnackbar("Please enter a valid email address.", isError: true);
      } else {
        // Generic error for other system issues
        _showSnackbar("System error. Please try again later.", isError: true);
      }
    } on TimeoutException catch (_) {
      if (!mounted) return;
      _showSnackbar("Connection timed out. Please check your network.", isError: true);
    } catch (e) {
      if (!mounted) return;
      _showSnackbar("An unexpected error occurred.", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _emailFocusNode.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: theme.colorScheme.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text("Reset Password", style: TextStyle(color: Colors.white)),
        ),
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Image.asset(
                'assets/background/bg_fp.png', 
                alignment: Alignment.bottomCenter,
                fit: BoxFit.cover, // Ensure it covers nicely
              ),
            ),
            // Form Content
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    _buildEmailInput(theme),
                    const SizedBox(height: 20),
                    _buildActionButton(theme),
                  ],
                ),
              ),
            ),
            // Overlay Loading
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: theme.colorScheme.secondary),
                      const SizedBox(height: 20),
                      const Text(
                        'Sending link...',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailInput(ThemeData theme) {
    return TextFormField(
      controller: _emailController,
      focusNode: _emailFocusNode,
      cursorColor: theme.colorScheme.secondary,
      decoration: InputDecoration(
        labelText: 'Enter your email',
        labelStyle: TextStyle(color: theme.colorScheme.primary),
        filled: true,
        fillColor: Colors.white.withOpacity(0.9), // Better readability on bg image
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        prefixIcon: const Icon(Icons.email),
      ),
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
          return 'Enter a valid email address';
        }
        return null;
      },
    );
  }

  Widget _buildActionButton(ThemeData theme) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _sendResetLink, // Disable button while loading
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: const Text(
        'Send Reset Link',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose(); // Don't forget to dispose focus nodes!
    super.dispose();
  }
}