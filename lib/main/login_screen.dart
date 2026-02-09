import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:otakulink/main/home_screen.dart';
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
  final _formKey = GlobalKey<FormState>();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _showResendButton = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _login() async {
    FocusManager.instance.primaryFocus?.unfocus(); // Cleaner keyboard dismissal

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _showResendButton = false;
    });

    try {
      String input = _emailController.text.trim();
      String emailToUse = input;

      // 1. Username Resolution
      // Note: Ensure you have a Firestore Index on the 'username' field.
      final isEmail = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(input);
      
      if (!isEmail) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: input)
            .limit(1)
            .get();

        if (querySnapshot.docs.isEmpty) {
          throw FirebaseAuthException(
            code: 'user-not-found', // Use standard codes for standard handling
            message: 'User not found.',
          );
        }
        emailToUse = querySnapshot.docs.first.get('email');
      }

      // 2. Authentication
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: emailToUse,
        password: _passwordController.text,
      );

      User user = userCredential.user!;

      // 3. Verification Check
      if (!user.emailVerified) {
        // Optional: Only send if they ask, or send automatically. 
        // Automatic sending can trigger spam limits.
        if (mounted) {
           _showSnackbar(
            "Email not verified. Please check your inbox.", 
            isError: true,
          );
          setState(() => _showResendButton = true);
          await _auth.signOut();
        }
      } else {
        // 4. Secure Caching & Navigation
        await _cacheUserData(user);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnackbar(_getSecureErrorMessage(e), isError: true);
    } catch (e) {
      if (!mounted) return;
      // Log this error to Crashlytics in production
      _showSnackbar("An unexpected error occurred. Try again.", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cacheUserData(User user) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        // Safe Direct Access (Main has ensured the box is open)
        var box = Hive.box('userCache'); 
            
        await box.putAll({
          'email': user.email!,
          'uid': user.uid,
          'username': userDoc.get('username'),
        });
        
        if (mounted) _navigateTo(const HomeScreen());
      } else {
        await _auth.signOut();
        if (mounted) _showSnackbar("Account data not found.", isError: true);
      }
    } on FirebaseException catch (e) {
      // 👈 NEW: Handle Security Rule Rejections
      if (e.code == 'permission-denied') {
        _auth.signOut();
        if (mounted) _showSnackbar("Security Alert: Access denied.", isError: true);
      } else {
        if (mounted) _showSnackbar("Database error: ${e.message}", isError: true);
      }
    } catch (e) {
       if (mounted) _showSnackbar("System error. Please restart.", isError: true);
    }
  }

  // Helper: Secure Error Messages
  String _getSecureErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email, username, or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many login attempts. Try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  Future<void> _resendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        _showSnackbar("Verification email sent!", isError: false);
        await _auth.signOut();
        setState(() => _showResendButton = false);
      }
    } catch (e) {
      _showSnackbar("Too many requests. Wait a moment.", isError: true);
    }
  }

  void _showSnackbar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    final theme = Theme.of(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: theme.colorScheme.onError,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: theme.colorScheme.onError),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? theme.colorScheme.error : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => FadeTransition(opacity: animation, child: screen),
        transitionDuration: const Duration(milliseconds: 300),
      ),
      (route) => false, // Remove Login from back stack
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: AbsorbPointer(
          absorbing: _isLoading,
          child: Stack(
            children: [
              Center(
                // ConstrainedBox handles tablets/web gracefully
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: AutofillGroup( // 👈 ENABLE PASSWORD MANAGERS
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Ensure asset exists or wrap in error builder
                            Image.asset('assets/logo/logo_flat1.png', height: 150),
                            const SizedBox(height: 20),
                            Text(
                              'Welcome to OtakuLink',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 30),
                            
                            // Email Field
                            TextFormField(
                              controller: _emailController,
                              cursorColor: theme.colorScheme.primary,
                              autofillHints: const [AutofillHints.email, AutofillHints.username],
                              style: theme.textTheme.bodyLarge, // Standardized text style
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                label: 'Email / Username',
                                icon: Icons.person,
                                theme: theme,
                              ),
                              validator: (value) => (value == null || value.isEmpty) 
                                  ? 'Please enter your email or username' : null,
                            ),
                            const SizedBox(height: 20),

                            // Password Field
                            TextFormField(
                              controller: _passwordController,
                              cursorColor: theme.colorScheme.primary,
                              autofillHints: const [AutofillHints.password],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _login(), // Login on "Enter"
                              decoration: _inputDecoration(
                                label: 'Password',
                                icon: Icons.lock,
                                theme: theme,
                                suffix: IconButton(
                                  icon: Icon(
                                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                ),
                              ),
                              obscureText: !_isPasswordVisible,
                              validator: (value) => (value == null || value.length < 6) 
                                  ? 'Password must be at least 6 characters' : null,
                            ),

                            _buildForgotPasswordLink(theme),
                            const SizedBox(height: 10),
                            
                            // Login Button
                            ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: _isLoading 
                                ? SizedBox(
                                    height: 20, width: 20, 
                                    child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary)
                                  )
                                : const Text('Log In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),

                            if (_showResendButton)
                              TextButton(
                                onPressed: _resendVerificationEmail,
                                child: const Text("Resend Verification Email"),
                              ),
                              
                            const SizedBox(height: 20),
                            _buildSignUpLink(theme),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_isLoading)
                Positioned.fill(
                  child: AbsorbPointer( // This blocks all touch events
                    child: Container(
                      color: Colors.black.withOpacity(0.5), // Dim the background
                      child: Center(
                        child: CircularProgressIndicator(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPasswordLink(ThemeData theme) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _isLoading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
        child: Text(
          'Forgot Password?',
          style: TextStyle(
            color: _isLoading ? theme.disabledColor : theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpLink(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Don’t have an account?', style: theme.textTheme.bodyMedium),
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen())),
          child: Text(
            'Sign Up',
            style: TextStyle(
              color: _isLoading ? theme.disabledColor : theme.colorScheme.secondary, // Using orange accent
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String label, 
    required IconData icon, 
    required ThemeData theme, 
    Widget? suffix
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: theme.colorScheme.primary),
      suffixIcon: suffix,
      // The rest (borders, fill color) is handled by inputDecorationTheme in app_theme.dart
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}