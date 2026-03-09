import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/supabase_provider.dart';
import '../widgets/auth_widgets.dart';

class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  bool _isLoading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkVerification(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerification() async {
    final supabase = ref.read(supabaseClientProvider);
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final session = await supabase.auth.refreshSession();
      if (session.user?.emailConfirmedAt != null) {
        _timer?.cancel();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("Verification check failed: $e");
    }
  }

  Future<void> _sendVerificationEmail() async {
    setState(() => _isLoading = true);
    final supabase = ref.read(supabaseClientProvider);

    try {
      final user = supabase.auth.currentUser;
      if (user?.email != null) {
        await supabase.auth.resend(type: OtpType.signup, email: user!.email!);
        _showSnackbar("Verification email sent! Check your inbox.");
      }
    } catch (e) {
      _showSnackbar("Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Verify Email"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(supabaseClientProvider).auth.signOut(),
          ),
        ],
      ),
      body: AuthWrapper(
        isLoading: _isLoading,
        child: Column(
          children: [
            Icon(
              Icons.mark_email_unread_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 20),
            const Text(
              "Check your Inbox",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "We have sent a verification link to your email. Please click it to continue.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            PrimaryButton(
              text: "I have verified my email",
              isLoading: _isLoading,
              onPressed: _checkVerification,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _isLoading ? null : _sendVerificationEmail,
              child: const Text("Resend Verification Email"),
            ),
          ],
        ),
      ),
    );
  }
}
