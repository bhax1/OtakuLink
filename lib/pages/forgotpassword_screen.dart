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
  bool _isLoading = false;

  // Send reset link logic using Firebase Auth
  void _sendResetLink() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Send reset email using Firebase Auth
        await FirebaseAuth.instance.sendPasswordResetEmail(
          email: _emailController.text.trim(),
        );

        setState(() {
          _isLoading = false;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset link sent to your email!')),
        );
      } on FirebaseAuthException catch (e) {
        setState(() {
          _isLoading = false;
        });
        // Handle specific errors
        String message = 'An error occurred';
        if (e.code == 'user-not-found') {
          message =
              'No user found for that email. Please check the email or sign up.';
        } else if (e.code == 'invalid-email') {
          message = 'The email address is not valid.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
        });

        // Generic error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Something went wrong. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Color(0xFF33415C); // Primary color for styling

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
      ),
      resizeToAvoidBottomInset: false, // Avoid resizing on keyboard display
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/background/bg_fp.png', // Add your image path here
              alignment: Alignment.bottomCenter,
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
                  _buildTitle(primaryColor),
                  SizedBox(height: 20),
                  _buildEmailInput(),
                  SizedBox(height: 20),
                  _buildActionButton(primaryColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Title Widget
  Widget _buildTitle(Color primaryColor) {
    return Text(
      'Reset your password',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: primaryColor,
      ),
      textAlign: TextAlign.center,
    );
  }

  // Email input field widget
  Widget _buildEmailInput() {
    return TextFormField(
      controller: _emailController,
      decoration: InputDecoration(
        labelText: 'Enter your email',
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

  // Action button widget
  Widget _buildActionButton(Color primaryColor) {
    return _isLoading
        ? Center(
            child: CircularProgressIndicator(
              color: primaryColor,
            ),
          )
        : ElevatedButton(
            onPressed: _sendResetLink,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
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
    super.dispose();
  }
}
