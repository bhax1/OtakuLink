import 'dart:async'; // For TimeoutException
import 'dart:io';   // For InternetAddress.lookup

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 1. IMPROVED SNACKBAR DESIGN
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

  // 2. HARDENED SIGN UP LOGIC
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    _nameFocusNode.unfocus();
    _emailFocusNode.unfocus();
    _passwordFocusNode.unfocus();
    _confirmPasswordFocusNode.unfocus();

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
      // B. VALIDATION LOGIC
      if (RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(_nameController.text)) {
        throw FirebaseAuthException(
          code: 'invalid-username',
          message: 'Email addresses cannot be used as usernames.',
        );
      }

      // C. USERNAME UNIQUENESS CHECK (With Timeout)
      QuerySnapshot usernameQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: _nameController.text)
          .get()
          .timeout(const Duration(seconds: 10));

      if (usernameQuery.docs.isNotEmpty) {
        throw FirebaseAuthException(
          code: 'username-already-in-use',
          message: 'This username is already taken.',
        );
      }

      // D. CREATE AUTH USER (With Timeout)
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          )
          .timeout(const Duration(seconds: 15));

      // E. SAVE TO FIRESTORE (With Timeout)
      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'username': _nameController.text.trim(),
            'email': _emailController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 10));

      // F. SEND VERIFICATION
      await userCredential.user!.sendEmailVerification();

      if (!mounted) return;

      // G. SUCCESS UI
      // Use MaterialBanner for critical info like verification
      ScaffoldMessenger.of(context).showMaterialBanner(
        MaterialBanner(
          content: const Text(
            'Account created! A verification email has been sent.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green, // Success color
          leading: const Icon(Icons.mark_email_read, color: Colors.white),
          actions: [
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              },
              child: const Text('DISMISS', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      // Auto-hide banner after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      });

      // Navigate to login
      Navigator.of(context).pushReplacement(_createFadeTransitionRoute());

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      
      String errorMessage = 'An error occurred';
      if (e.code == 'invalid-email') {
        errorMessage = 'Email address is invalid.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Password is too weak.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'This email is already in use.';
      } else if (e.code == 'username-already-in-use') {
        errorMessage = 'This username is already taken.';
      } else if (e.code == 'invalid-username') {
        errorMessage = e.message ?? 'Invalid username.';
      }

      _showSnackbar(errorMessage, isError: true);
    
    } on TimeoutException catch (_) {
      if (!mounted) return;
      _showSnackbar("Connection timed out. Please check your internet.", isError: true);
    } catch (e) {
      if (!mounted) return;
      _showSnackbar("An unexpected error occurred. Please try again.", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Access the theme

    return GestureDetector(
      onTap: () {
        _nameFocusNode.unfocus();
        _emailFocusNode.unfocus();
        _passwordFocusNode.unfocus();
        _confirmPasswordFocusNode.unfocus();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Center(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 40),
                        Image.asset(
                          'assets/gif/signup.gif',
                          height: 100,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Create Your Account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary, // Use Theme color
                          ),
                        ),
                        const SizedBox(height: 30),
                        _buildNameInput(theme),
                        const SizedBox(height: 20),
                        _buildEmailInput(theme),
                        const SizedBox(height: 20),
                        _buildPasswordInput(theme),
                        const SizedBox(height: 20),
                        _buildConfirmPasswordInput(theme),
                        const SizedBox(height: 20),
                        _buildSignUpButton(theme),
                        const SizedBox(height: 20),
                        _buildLoginLink(theme),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
                        'Signing up...',
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

  Widget _buildNameInput(ThemeData theme) {
    return TextFormField(
      controller: _nameController,
      focusNode: _nameFocusNode,
      cursorColor: theme.colorScheme.secondary,
      decoration: _inputDecoration(
        label: 'Username',
        icon: Icons.person,
        theme: theme,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your username';
        }
        return null;
      },
    );
  }

  Widget _buildEmailInput(ThemeData theme) {
    return TextFormField(
      controller: _emailController,
      focusNode: _emailFocusNode,
      cursorColor: theme.colorScheme.secondary,
      decoration: _inputDecoration(
        label: 'Email', 
        icon: Icons.email,
        theme: theme,
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

  Widget _buildPasswordInput(ThemeData theme) {
    return TextFormField(
      controller: _passwordController,
      focusNode: _passwordFocusNode,
      cursorColor: theme.colorScheme.secondary,
      decoration: _inputDecoration(
        label: 'Password',
        icon: Icons.lock,
        theme: theme,
        suffix: IconButton(
          icon: Icon(
              _isPasswordVisible ? Icons.visibility : Icons.visibility_off),
          onPressed: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        ),
      ),
      obscureText: !_isPasswordVisible,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a password';
        } else if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordInput(ThemeData theme) {
    return TextFormField(
      controller: _confirmPasswordController,
      focusNode: _confirmPasswordFocusNode,
      cursorColor: theme.colorScheme.secondary,
      decoration: _inputDecoration(
        label: 'Confirm Password',
        icon: Icons.lock,
        theme: theme,
        suffix: IconButton(
          icon: Icon(_isConfirmPasswordVisible
              ? Icons.visibility
              : Icons.visibility_off),
          onPressed: () {
            setState(() {
              _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
            });
          },
        ),
      ),
      obscureText: !_isConfirmPasswordVisible,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please confirm your password';
        } else if (value != _passwordController.text) {
          return 'Passwords do not match';
        }
        return null;
      },
    );
  }

  Widget _buildSignUpButton(ThemeData theme) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _signUp,
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text(
        'Sign Up',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLoginLink(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Already have an account?'),
        TextButton(
          onPressed: () {
            Navigator.of(context).pushReplacement(_createFadeTransitionRoute());
          },
          child: Text(
            'Login',
            style: TextStyle(color: theme.colorScheme.secondary),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(
      {required String label, required IconData icon, required ThemeData theme, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: theme.colorScheme.primary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
    );
  }

  PageRouteBuilder _createFadeTransitionRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = 0.0;
        const end = 1.0;
        const curve = Curves.easeInOut;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var fadeAnimation = animation.drive(tween);

        return FadeTransition(opacity: fadeAnimation, child: child);
      },
    );
  }
}