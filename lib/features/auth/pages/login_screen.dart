import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Add Riverpod
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:otakulink/core/utils/app_snackbar.dart';
import 'package:otakulink/core/widgets/animations/login_animations.dart';
import 'package:otakulink/core/widgets/auth_widgets.dart';
import 'package:otakulink/features/auth/data/auth_repository.dart';

// Convert to ConsumerStatefulWidget
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  static bool _hasAnimated = false;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  // REMOVED: final _repository = AuthRepository();

  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  late AnimationController _controller;
  late LoginEnterAnimations _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _anim = LoginEnterAnimations(_controller);

    if (!LoginScreen._hasAnimated) {
      _controller.forward();
      LoginScreen._hasAnimated = true;
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);

      await authRepo.login(
        identifier: _identifierController.text,
        password: _passwordController.text,
      );
    } on AuthException catch (e) {
      AppSnackBar.show(context, e.message, type: SnackBarType.error);
    } catch (_) {
      AppSnackBar.show(context, "Unexpected error occurred.",
          type: SnackBarType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  FadeTransition(
                    opacity: _anim.logoFade,
                    child: ScaleTransition(
                      scale: _anim.logoScale,
                      child: Image.asset('assets/logo/logo_flat2.png',
                          height: 150),
                    ),
                  ),

                  // Slogan
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildAnimatedWord(
                          "Your ", _anim.word1Fade, _anim.word1Slide),
                      _buildAnimatedWord(
                          "World, ", _anim.word2Fade, _anim.word2Slide),
                      _buildAnimatedWord(
                          "Linked!", _anim.word3Fade, _anim.word3Slide),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Email
                  FadeTransition(
                    opacity: _anim.emailFade,
                    child: SlideTransition(
                      position: _anim.emailSlide,
                      child: CustomTextField(
                        controller: _identifierController,
                        label: 'Email or Username',
                        prefixIcon: Icons.person_outline,
                        autofillHints: const [
                          AutofillHints.email,
                          AutofillHints.username
                        ],
                        action: TextInputAction.next,
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ),

                  // Password
                  FadeTransition(
                    opacity: _anim.passFade,
                    child: SlideTransition(
                      position: _anim.passSlide,
                      child: CustomTextField(
                        controller: _passwordController,
                        label: 'Password',
                        prefixIcon: Icons.lock_outline,
                        isPassword: true,
                        isVisible: _isPasswordVisible,
                        onVisibilityToggle: () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible),
                        autofillHints: const [AutofillHints.password],
                        action: TextInputAction.done,
                        onSubmitted: (_) => _handleLogin(),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ),

                  // Forgot Password
                  ScaleTransition(
                    scale: _anim.forgotScale,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        child: Text("Forgot Password?",
                            style:
                                TextStyle(color: theme.colorScheme.secondary)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Button
                  FadeTransition(
                    opacity: _anim.btnFade,
                    child: SlideTransition(
                      position: _anim.btnSlide,
                      child: PrimaryButton(
                        text: "Log In",
                        isLoading: _isLoading,
                        onPressed: _handleLogin,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Footer
                  FadeTransition(
                    opacity: _anim.footerFade,
                    child: AuthFooterLink(
                      text: "Don't have an account?",
                      actionText: "Sign Up",
                      onTap: () => context.push('/signup'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedWord(
      String text, Animation<double> fade, Animation<Offset> slide) {
    return SlideTransition(
      position: slide,
      child: FadeTransition(
        opacity: fade,
        child: Text(
          text,
          style: GoogleFonts.yomogi(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
