import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:otakulink/main.dart';
import 'package:otakulink/pages/home_screen.dart';
import 'forgotpassword_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers for input fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();

  // Password visibility toggle
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  // Firebase Auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Method: Handles user login
  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      _emailFocusNode.unfocus(); // Unfocus both fields
      _passwordFocusNode.unfocus();
      setState(() => _isLoading = true);

      try {
        String emailOrUsername = _emailController.text;
        String emailToUse = emailOrUsername;

        // Check if input is not an email format
        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(emailOrUsername)) {
          // Search Firestore for a matching username
          QuerySnapshot querySnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('username', isEqualTo: emailOrUsername)
              .limit(1)
              .get();

          if (querySnapshot.docs.isEmpty) {
            throw FirebaseAuthException(
              code: 'user-not-found',
              message: 'Username not found. Please check and try again.',
            );
          }

          // Retrieve the associated email
          emailToUse = querySnapshot.docs.first.get('email');
        }

        // Sign in using the resolved email
        final userCredential = await _auth.signInWithEmailAndPassword(
          email: emailToUse,
          password: _passwordController.text,
        );

        if (!userCredential.user!.emailVerified) {
          _showSnackbar('Please verify your email first.');
        } else {
          String uid = userCredential.user!.uid;
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();

          Map<String, dynamic>? userData =
              userDoc.data() as Map<String, dynamic>?;

          var box = Hive.box('userCache');
          box.put('email', userCredential.user!.email!);
          box.put('uid', uid);
          box.put('username', userData?['username'] ?? 'Default Username');

          if (mounted) {
            _navigateTo(const HomeScreen());
          }
        }
      } on FirebaseAuthException catch (e) {
        _showSnackbar(_getErrorMessage(e));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // Helper: Displays a snackbar
  void _showSnackbar(String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(message),
          duration: duration ?? const Duration(seconds: 3)),
    );
  }

  // Helper: Fetches error messages
  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email or password is incorrect. Please try again.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }

  // Navigation helper with fade transition
  void _navigateTo(Widget screen) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) =>
            FadeTransition(opacity: animation, child: screen),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  // Show a full-screen overlay with "Logging in..." message
  Widget _buildOverlay() {
    return _isLoading
        ? Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: accentColor),
                    SizedBox(height: 20),
                    Text(
                      'Logging in...',
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
          )
        : SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _emailFocusNode.unfocus();
        _passwordFocusNode.unfocus();
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset('assets/logo/logo_flat1.png', height: 150),
                      const SizedBox(height: 20),
                      _buildWelcomeText(),
                      const SizedBox(height: 30),
                      _buildEmailField(),
                      const SizedBox(height: 20),
                      _buildPasswordField(),
                      _buildForgotPasswordLink(),
                      const SizedBox(height: 10),
                      _buildLoginButton(),
                      const SizedBox(height: 20),
                      _buildSignUpLink(),
                    ],
                  ),
                ),
              ),
            ),
            _buildOverlay(),
          ],
        ),
      ),
    );
  }

  // UI: Welcome text
  Widget _buildWelcomeText() {
    return Text(
      'Welcome to OtakuLink',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: primaryColor,
            fontWeight: FontWeight.bold,
          ),
    );
  }

  // UI: Email/Username input field
  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      focusNode: _emailFocusNode,
      cursorColor: accentColor,
      decoration: _inputDecoration(
        label: 'Email / Username',
        icon: Icons.person,
      ),
      validator: (value) {
        if (value == null || value.isEmpty)
          return 'Please enter your email or username';
        return null;
      },
    );
  }

  // UI: Password input field
  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      focusNode: _passwordFocusNode,
      cursorColor: accentColor,
      decoration: _inputDecoration(
        label: 'Password',
        icon: Icons.lock,
        suffix: IconButton(
          icon: Icon(
              _isPasswordVisible ? Icons.visibility : Icons.visibility_off),
          onPressed: () =>
              setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
      ),
      obscureText: !_isPasswordVisible,
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter your password';
        if (value.length < 6)
          return 'Password must be at least 6 characters long';
        return null;
      },
    );
  }

  // UI: Forgot password link
  Widget _buildForgotPasswordLink() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed:
            _isLoading ? null : () => _navigateTo(const ForgotPasswordScreen()),
        child: Text(
          'Forgot Password?',
          style: TextStyle(color: _isLoading ? Colors.grey : accentColor),
        ),
      ),
    );
  }

  // UI: Login button
  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _login,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text('Log In',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
    );
  }

  // UI: Sign-up link
  Widget _buildSignUpLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Don’t have an account?'),
        TextButton(
          onPressed:
              _isLoading ? null : () => _navigateTo(const SignUpScreen()),
          child: Text(
            'Sign Up',
            style: TextStyle(color: _isLoading ? Colors.grey : accentColor),
          ),
        ),
      ],
    );
  }

  // Helper: Common input field decoration
  InputDecoration _inputDecoration(
      {required String label, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: primaryColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }
}
