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
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _showResendButton = false; // 👈 new

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      _emailFocusNode.unfocus();
      _passwordFocusNode.unfocus();
      setState(() {
        _isLoading = true;
        _showResendButton = false; // reset each login attempt
      });

      try {
        String emailOrUsername = _emailController.text;
        String emailToUse = emailOrUsername;

        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(emailOrUsername)) {
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
          emailToUse = querySnapshot.docs.first.get('email');
        }

        final userCredential = await _auth.signInWithEmailAndPassword(
          email: emailToUse,
          password: _passwordController.text,
        );

        User user = userCredential.user!;
        if (!user.emailVerified) {
          await user.sendEmailVerification(); // 👈 auto resend
          _showSnackbar(
            "Your email is not verified or the link expired.\n"
            "We’ve sent a new verification email.",
          );
          setState(() => _showResendButton = true); // 👈 show button
          await _auth.signOut();
        } else {
          String uid = user.uid;
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();

          Map<String, dynamic>? userData =
              userDoc.data() as Map<String, dynamic>?;

          var box = Hive.box('userCache');
          box.put('email', user.email!);
          box.put('uid', uid);
          box.put('username', userData?['username'] ?? 'Default Username');

          if (mounted) _navigateTo(const HomeScreen());
        }
      } on FirebaseAuthException catch (e) {
        _showSnackbar(_getErrorMessage(e));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        _showSnackbar("New verification email sent!");
        await _auth.signOut();
      } else {
        _showSnackbar("Login first to resend verification email.");
      }
    } catch (e) {
      _showSnackbar("Error sending verification email.");
    }
  }

  void _showSnackbar(String message, {Duration? duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }

  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
        return 'Incorrect email, username, or password.\nPlease try again.';
      case 'user-not-found':
      case 'invalid-email':
        return 'Email or username not found. Please check your credentials.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      default:
        return e.message ?? 'An unexpected error occurred. Please try again.';
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) =>
            FadeTransition(opacity: animation, child: screen),
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

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
                    const SizedBox(height: 20),
                    const Text(
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
        : const SizedBox.shrink();
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
                      if (_showResendButton) // 👈 only shows after failed login
                        TextButton(
                          onPressed: _resendVerificationEmail,
                          child: const Text("Resend Verification Email"),
                        ),
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
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () =>
              setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
      ),
      obscureText: !_isPasswordVisible,
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter your password';
        if (value.length < 6) return 'Password must be at least 6 characters long';
        return null;
      },
    );
  }

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

  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _login,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Text(
        'Log In',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 16,
        ),
      ),
    );
  }

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
