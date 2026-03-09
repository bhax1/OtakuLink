import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/app_snackbar.dart';
import '../controllers/auth_controller.dart';
import '../widgets/animations/login_animations.dart';
import '../widgets/auth_widgets.dart';

// Convert to ConsumerStatefulWidget
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  static bool _hasAnimated = false;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
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

    if (!LoginPage._hasAnimated) {
      _controller.forward();
      LoginPage._hasAnimated = true;
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
      final authController = ref.read(authControllerProvider.notifier);

      await authController.login(
        _identifierController.text.trim(),
        _passwordController.text,
      );
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
                      child: Image.asset(
                        'assets/logo/logo_flat2.png',
                        height: 150,
                      ),
                    ),
                  ),

                  // Slogan
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildAnimatedWord(
                        "Your ",
                        _anim.word1Fade,
                        _anim.word1Slide,
                      ),
                      _buildAnimatedWord(
                        "World, ",
                        _anim.word2Fade,
                        _anim.word2Slide,
                      ),
                      _buildAnimatedWord(
                        "Linked!",
                        _anim.word3Fade,
                        _anim.word3Slide,
                      ),
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
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [
                          AutofillHints.email,
                          AutofillHints.username,
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
                        keyboardType: TextInputType.visiblePassword,
                        isPassword: true,
                        isVisible: _isPasswordVisible,
                        onVisibilityToggle: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
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
                        child: Text(
                          "Forgot Password?",
                          style: TextStyle(color: theme.colorScheme.secondary),
                        ),
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

                  const SizedBox(height: 10),

                  // Legal Links
                  FadeTransition(
                    opacity: _anim.footerFade,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () =>
                              context.push('/settings/privacy-policy'),
                          child: Text(
                            "Privacy Policy",
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.5,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          "•",
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.3),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              context.push('/settings/terms-of-service'),
                          child: Text(
                            "Terms of Service",
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Guest Button (Ghost Style)
                  FadeTransition(
                    opacity: _anim.footerFade,
                    child: Center(
                      child: OutlinedButton(
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('isGuest', true);
                          if (!mounted) return;
                          context.go('/');
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                          side: BorderSide(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.2,
                            ),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.explore_outlined,
                              size: 18,
                              color: theme.colorScheme.secondary,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Browse as Guest',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
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
    String text,
    Animation<double> fade,
    Animation<Offset> slide,
  ) {
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
