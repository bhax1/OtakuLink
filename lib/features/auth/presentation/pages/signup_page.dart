import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/validators.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_widgets.dart';

// Convert to ConsumerStatefulWidget
class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  // REMOVED: final _repository = AuthRepository();
  final _formKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _attemptSignUp() {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreedToTerms) {
      AppSnackBar.show(
        context,
        "You must agree to the Terms of Service.",
        type: SnackBarType.error,
      );
      return;
    }

    _executeSignUp();
  }

  Future<void> _executeSignUp() async {
    setState(() => _isLoading = true);

    try {
      final authController = ref.read(authControllerProvider.notifier);

      await authController.signUp(
        _emailController.text.trim(),
        _usernameController.text.trim(),
        _passwordController.text,
        displayName: _displayNameController.text.trim().isNotEmpty
            ? _displayNameController.text.trim()
            : null,
      );

      if (!mounted) return;

      AppSnackBar.show(
        context,
        'Account created! Verification email sent.',
        type: SnackBarType.success,
      );

      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        context.go('/login');
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, e.message, type: SnackBarType.error);
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        "Unexpected error occurred.",
        type: SnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... [Keep your entire build method and UI exactly as it was] ...
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Theme.of(context).scaffoldBackgroundColor,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: AuthWrapper(
          isLoading: _isLoading,
          alignment: Alignment.topCenter,
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  Image.asset('assets/gif/signup.gif', height: 80),
                  const SizedBox(height: 20),
                  Text(
                    'Create Account',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.yomogi(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // CORE FIELDS
                  CustomTextField(
                    controller: _usernameController,
                    label: 'Username (@handle)',
                    prefixIcon: Icons.alternate_email,
                    autofillHints: const [AutofillHints.newUsername],
                    validator: AppValidators.validateUsername,
                    // helpText: "This is your unique identifier.",
                  ),
                  CustomTextField(
                    controller: _displayNameController,
                    label: 'Display Name',
                    prefixIcon: Icons.badge_outlined,
                    autofillHints: const [AutofillHints.name],
                    validator: (v) =>
                        AppValidators.validateRequired(v, 'Display Name'),
                  ),
                  CustomTextField(
                    controller: _emailController,
                    label: 'Email',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: AppValidators.validateEmail,
                  ),
                  CustomTextField(
                    controller: _passwordController,
                    label: 'Password',
                    prefixIcon: Icons.lock_outline,
                    isPassword: true,
                    isVisible: _isPasswordVisible,
                    autofillHints: const [AutofillHints.newPassword],
                    onVisibilityToggle: () => setState(
                      () => _isPasswordVisible = !_isPasswordVisible,
                    ),
                    validator: AppValidators.validatePassword,
                  ),
                  CustomTextField(
                    controller: _confirmController,
                    label: 'Confirm Password',
                    prefixIcon: Icons.lock_clock_outlined,
                    isPassword: true,
                    isVisible: _isPasswordVisible,
                    validator: (value) => AppValidators.confirmPassword(
                      _passwordController.text,
                      value,
                    ),
                  ),

                  // TERMS CHECKBOX
                  Row(
                    children: [
                      Checkbox(
                        value: _agreedToTerms,
                        onChanged: (value) =>
                            setState(() => _agreedToTerms = value ?? false),
                      ),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: Theme.of(context).textTheme.bodySmall,
                            children: [
                              const TextSpan(text: "I agree to the "),
                              TextSpan(
                                text: "Terms of Service",
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    context.push('/settings/terms-of-service');
                                  },
                              ),
                              const TextSpan(text: " and "),
                              TextSpan(
                                text: "Privacy Policy",
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    context.push('/settings/privacy-policy');
                                  },
                              ),
                              const TextSpan(text: "."),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  PrimaryButton(
                    text: "Sign Up",
                    isLoading: _isLoading,
                    onPressed: _attemptSignUp,
                  ),
                  const SizedBox(height: 10),

                  AuthFooterLink(
                    text: "Already have an account?",
                    actionText: "Login",
                    onTap: () => context.go('/login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
