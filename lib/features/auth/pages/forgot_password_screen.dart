import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ADD THIS
import 'package:google_fonts/google_fonts.dart';
import 'package:otakulink/core/widgets/auth_widgets.dart';
import 'package:otakulink/features/auth/data/auth_repository.dart';
import 'package:otakulink/core/utils/app_snackbar.dart';

// Convert to ConsumerStatefulWidget
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  // REMOVED: final _repository = AuthRepository();
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // READ REPOSITORY FROM PROVIDER
      final authRepo = ref.read(authRepositoryProvider);

      await authRepo.sendPasswordReset(_emailController.text.trim());

      if (!mounted) return;

      AppSnackBar.show(
          context, "If an account exists, a reset link has been sent.",
          type: SnackBarType.success);

      _emailController.clear();
    } on AuthException catch (e) {
      AppSnackBar.show(context, e.message, type: SnackBarType.error);
    } catch (_) {
      AppSnackBar.show(context, "An unexpected error occurred.",
          type: SnackBarType.error);
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
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          iconTheme: Theme.of(context).iconTheme,
        ),
        body: AuthWrapper(
          isLoading: _isLoading,
          alignment: Alignment.topCenter,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock_reset,
                    size: 80, color: Color(0xFF33415C)),
                const SizedBox(height: 20),
                Text(
                  "Forgot your password?",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.yomogi(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Enter your email address and we will send you a link to reset it.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),
                CustomTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  action: TextInputAction.done,
                  onSubmitted: (_) => _handleReset(),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Invalid email' : null,
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  text: "Send Reset Link",
                  isLoading: _isLoading,
                  onPressed: _handleReset,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
