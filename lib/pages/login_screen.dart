import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
  final _formKey = GlobalKey<FormState>();

  // Password visibility toggle
  bool _isPasswordVisible = false;
  bool _isLoading = false; // Add this for loading state

  // Firebase Auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Login logic
  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      // Dismiss the keyboard
      FocusScope.of(context).unfocus();

      // Show "Logging in..." snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Logging in..."),
          duration: Duration(seconds: 30), // Long duration to show during login
        ),
      );

      setState(() {
        _isLoading = true;
      });

      try {
        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (!userCredential.user!.emailVerified) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please verify your email first.')),
          );
        } else {
          // Navigate to HomeScreen with smooth transition
          Navigator.of(context).push(
            _createFadeTransitionRoute(HomeScreen()),
          );
        }
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        String errorMessage = e.message ?? 'An error occurred';
        if (e.code == 'wrong-password') {
          errorMessage = 'Email or password is incorrect. Please try again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Image.asset(
                    'assets/logo/logo_flat1.png',
                    height: 150,
                    width: 150,
                  ),
                  SizedBox(height: 20),
                  // Welcome text
                  _buildWelcomeText(),
                  SizedBox(height: 30),
                  // Email input field
                  _buildEmailField(),
                  SizedBox(height: 20),
                  // Password input field
                  _buildPasswordField(),
                  SizedBox(height: 1),
                  // Forgot password link
                  _buildForgotPasswordLink(),
                  SizedBox(height: 10),
                  // Log in button
                  _buildLoginButton(),
                  SizedBox(height: 20),
                  // Sign-up link
                  _buildSignUpLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Welcome text widget
  Widget _buildWelcomeText() {
    return Text(
      'Welcome to OtakuLink',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: primaryColor,
      ),
    );
  }

  // Email input field widget
  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      decoration: InputDecoration(
        labelText: 'Email',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        prefixIcon: Icon(Icons.email),
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

  // Password input field widget
  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      decoration: InputDecoration(
        labelText: 'Password',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        prefixIcon: Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
          ),
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
          return 'Please enter your password';
        } else if (value.length < 6) {
          return 'Password must be at least 6 characters long';
        }
        return null;
      },
    );
  }

  // Forgot password link widget
  Widget _buildForgotPasswordLink() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {
          Navigator.push(
            context,
            _createFadeTransitionRoute(ForgotPasswordScreen()),
          );
        },
        child: Text(
          'Forgot Password?',
          style: TextStyle(color: accentColor),
        ),
      ),
    );
  }

  // Log in button widget with loading state
  Widget _buildLoginButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _login, // Disable button if loading
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        padding: EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: _isLoading
          ? CircularProgressIndicator(color: Colors.white)
          : Text(
              'Log In',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  // Sign-up link widget
  Widget _buildSignUpLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Don’t have an account?'),
        TextButton(
          onPressed: () {
            Navigator.of(context).push(
              _createFadeTransitionRoute(SignUpScreen()),
            );
          },
          child: Text(
            'Sign Up',
            style: TextStyle(color: accentColor),
          ),
        ),
      ],
    );
  }

  // Custom fade transition route
  Route _createFadeTransitionRoute(Widget screen) {
    return PageRouteBuilder(
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeInOut;

        var opacityAnimation = animation.drive(
          Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve)),
        );

        return FadeTransition(
          opacity: opacityAnimation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return screen;
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}