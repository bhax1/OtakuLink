import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:otakulink/main.dart';
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
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Firebase instance
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign up method
  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();

      setState(() {
        _isLoading = true;
      });

      try {
        // Check if the username is an email
        if (RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(_nameController.text)) {
          throw FirebaseAuthException(
            code: 'invalid-username',
            message: 'Email addresses cannot be used as usernames.',
          );
        }

        // Check if the username already exists
        QuerySnapshot usernameQuery = await _firestore
            .collection('users')
            .where('username', isEqualTo: _nameController.text)
            .get();
        if (usernameQuery.docs.isNotEmpty) {
          throw FirebaseAuthException(
            code: 'username-already-in-use',
            message: 'This username is already taken.',
          );
        }

        // Sign up user with Firebase Auth
        UserCredential userCredential =
            await _auth.createUserWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        // Save additional data to Firestore, including the creation date
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'username': _nameController.text,
          'email': _emailController.text,
          'createdAt': FieldValue.serverTimestamp(), // Adding the creation date
        });

        // Send email verification
        await userCredential.user!.sendEmailVerification();
        
        // Show a banner to verify the email
        ScaffoldMessenger.of(context).showMaterialBanner(
          MaterialBanner(
            content: Text(
              'A verification email has been sent to your email address.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: primaryColor,
            leading: Icon(
              Icons.email,
              color: Colors.white,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                },
                child: Text(
                  'DISMISS',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );

        Future.delayed(Duration(seconds: 3), () {
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
          }
        });

        // Navigate to the login screen after successful signup with fade transition
        Navigator.of(context).push(_createFadeTransitionRoute());
      } on FirebaseAuthException catch (e) {
        String errorMessage = e.message ?? 'An error occurred';
        if (e.code == 'invalid-email') {
          errorMessage = 'Email address is invalid.';
        } else if (e.code == 'weak-password') {
          errorMessage =
              'Password is too weak. Please choose a stronger password.';
        } else if (e.code == 'email-already-in-use') {
          errorMessage = 'This email is already in use.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      SizedBox(height: 20),
                      Image.asset(
                        'assets/gif/signup.gif',
                        height: 100,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Create Your Account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      SizedBox(height: 30),
                      _buildNameInput(),
                      SizedBox(height: 20),
                      _buildEmailInput(),
                      SizedBox(height: 20),
                      _buildPasswordInput(),
                      SizedBox(height: 20),
                      _buildConfirmPasswordInput(),
                      SizedBox(height: 20),
                      _buildSignUpButton(),
                      SizedBox(height: 20),
                      _buildLoginLink(),
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
                    CircularProgressIndicator(color: accentColor),
                    SizedBox(height: 20),
                    Text(
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
    );
  }

  Widget _buildNameInput() {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: 'Username',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        prefixIcon: Icon(Icons.person),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your username';
        }
        return null;
      },
    );
  }

  Widget _buildEmailInput() {
    return TextFormField(
      controller: _emailController,
      decoration: InputDecoration(
        labelText: 'Email',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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

  Widget _buildPasswordInput() {
    return TextFormField(
      controller: _passwordController,
      decoration: InputDecoration(
        labelText: 'Password',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        prefixIcon: Icon(Icons.lock),
        suffixIcon: IconButton(
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

  Widget _buildConfirmPasswordInput() {
    return TextFormField(
      controller: _confirmPasswordController,
      decoration: InputDecoration(
        labelText: 'Confirm Password',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        prefixIcon: Icon(Icons.lock),
        suffixIcon: IconButton(
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

  Widget _buildSignUpButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _signUp,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        padding: EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        'Sign Up',
        style: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Already have an account?'),
        TextButton(
          onPressed: () {
            Navigator.of(context).push(_createFadeTransitionRoute());
          },
          child: Text(
            'Login',
            style: TextStyle(color: accentColor),
          ),
        ),
      ],
    );
  }

  // Create a fade transition route to LoginScreen
  PageRouteBuilder _createFadeTransitionRoute() {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => LoginScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = 0.0;
        const end = 1.0;
        const curve = Curves.easeInOut;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var fadeAnimation = animation.drive(tween);

        return FadeTransition(opacity: fadeAnimation, child: child);
      },
    );
  }
}