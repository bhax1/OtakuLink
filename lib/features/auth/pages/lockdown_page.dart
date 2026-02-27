import 'package:flutter/material.dart';
import 'package:otakulink/core/security/security_guard.dart';
import 'package:otakulink/core/widgets/auth_widgets.dart';

class LockdownPage extends StatelessWidget {
  const LockdownPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Disables back button
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AuthWrapper(
          isLoading: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.gpp_bad_rounded, color: Colors.redAccent, size: 80),
              const SizedBox(height: 24),
              const Text(
                "Security Integrity Failed",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              const Text(
                "OtakuLink cannot run on this device due to security restrictions (Root/Jailbreak detected).",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),
              
              // Customizing the PrimaryButton for a "Danger" action
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => SecurityGuard.lockdown(),
                  child: const Text("Close Application", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}