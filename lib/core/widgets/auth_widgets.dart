import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:otakulink/core/utils/app_snackbar.dart';

class AuthWrapper extends StatefulWidget {
  final bool isLoading;
  final Widget child;
  final Alignment alignment;

  const AuthWrapper({
    super.key,
    required this.isLoading,
    required this.child,
    this.alignment = Alignment.center,
  });

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  DateTime? _lastPressedAt;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final navigator = Navigator.of(context);

        if (navigator.canPop()) {
          navigator.pop();
          return;
        }

        final now = DateTime.now();
        final backButtonHasNotBeenPressedOrIsOld = _lastPressedAt == null ||
            now.difference(_lastPressedAt!) > const Duration(seconds: 2);

        if (backButtonHasNotBeenPressedOrIsOld) {
          _lastPressedAt = now;
          AppSnackBar.show(
            context,
            "Press back button again to exit the app.",
            type: SnackBarType.warning,
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        // Removed Scaffold wrapper here
        child: AbsorbPointer(
          absorbing: widget.isLoading,
          child: SafeArea(
            child: Align(
              alignment: widget.alignment,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData prefixIcon;
  final bool isPassword;
  final bool isVisible;
  final VoidCallback? onVisibilityToggle;
  final String? Function(String?)? validator;
  final TextInputAction? action;
  final void Function(String)? onSubmitted;
  final Iterable<String>? autofillHints;
  final TextInputType? keyboardType;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.isPassword = false,
    this.isVisible = false,
    this.onVisibilityToggle,
    this.validator,
    this.action,
    this.onSubmitted,
    this.autofillHints,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && !isVisible,
        autofillHints: autofillHints,
        textInputAction: action,
        onFieldSubmitted: onSubmitted,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(prefixIcon),
          border: const OutlineInputBorder(),
          suffixIcon: isPassword
              ? IconButton(
                  icon:
                      Icon(isVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: onVisibilityToggle,
                )
              : null,
        ),
        validator: validator,
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: const Color(0xFF33415C),
        foregroundColor: Colors.white,
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            )
          : Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class AuthFooterLink extends StatelessWidget {
  final String text;
  final String actionText;
  final VoidCallback onTap;

  const AuthFooterLink({
    super.key,
    required this.text,
    required this.actionText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(text),
        TextButton(
          onPressed: onTap,
          child: Text(actionText,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.secondary)),
        ),
      ],
    );
  }
}
