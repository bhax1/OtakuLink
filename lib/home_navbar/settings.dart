import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:otakulink/main.dart';
import 'package:otakulink/pages/login_screen.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  bool isDarkTheme = false;
  bool toggleFeature = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Change password with confirmation
  Future<void> _changePassword() async {
    String? newPassword;

    // Step 1: Show confirmation dialog
    bool confirmReset = await _showConfirmationDialog();
    if (!confirmReset) return;

    // Step 2: Proceed with password change if confirmed
    await showDialog(
      context: context,
      builder: (context) {
        TextEditingController passwordController = TextEditingController();

        return AlertDialog(
          title: const Text('Change Password'),
          content: TextField(
            controller: passwordController,
            decoration: const InputDecoration(hintText: 'Enter new password'),
            obscureText: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                newPassword = passwordController.text.trim();
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newPassword != null && newPassword!.isNotEmpty) {
      try {
        // Disable interactions by showing a loading dialog
        showDialog(
          context: context,
          barrierDismissible: false, // Prevent interaction outside the dialog
          builder: (context) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
        );

        final User? user = _auth.currentUser;

        // Step 3: Re-authenticate user before allowing password change (optional but recommended)
        if (user != null) {
          String? currentPassword;

          // Step 4: Request current password for re-authentication
          await showDialog(
            context: context,
            builder: (context) {
              TextEditingController passwordController = TextEditingController();
              return AlertDialog(
                title: const Text('Enter Current Password'),
                content: TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(hintText: 'Enter current password'),
                  obscureText: true,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      currentPassword = passwordController.text.trim();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Authenticate'),
                  ),
                ],
              );
            },
          );

          // Re-authenticate user before updating password
          if (currentPassword != null && currentPassword!.isNotEmpty) {
            AuthCredential credential = EmailAuthProvider.credential(
              email: user.email!,
              password: currentPassword!,
            );

            await user.reauthenticateWithCredential(credential);
          }
        }

        // Step 5: Update the password
        await _auth.currentUser?.updatePassword(newPassword!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully!')),
        );

        // Close the loading dialog
        Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update password: $e')),
        );
        // Close the loading dialog in case of an error
        Navigator.of(context).pop();
      }
    }
  }

  // Helper method to show confirmation dialog
  Future<bool> _showConfirmationDialog() async {
    bool confirmReset = false;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Are you sure you want to reset your password?'),
          content: const Text('This will change your current password.'),
          actions: [
            TextButton(
              onPressed: () {
                confirmReset = false;
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                confirmReset = true;
                Navigator.of(context).pop();
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
    return confirmReset;
  }

  // Delete account with confirmation
  Future<void> _deleteAccount() async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    String? password;

    await showDialog(
      context: context,
      builder: (context) {
        TextEditingController passwordController = TextEditingController();

        return AlertDialog(
          title: const Text('Confirm Account Deletion'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Deleting your account is irreversible and all your data will be permanently lost. Are you sure you want to continue?',
                style: TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(hintText: 'Enter your password'),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                password = passwordController.text.trim();
                Navigator.of(context).pop();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (password != null && password!.isNotEmpty) {
      try {
        // Re-authenticate the user before deletion
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password!,
        );
        await user.reauthenticateWithCredential(credential);

        // Delete user's data from Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();

        // Delete the user account
        await user.delete();

        // Navigate to login screen after deletion
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Image.asset('assets/logo/logo_flat2.png', height: 200),
            ),
            ListTile(
              leading: const Icon(Icons.lock, color: Colors.blueGrey),
              title: const Text('Change Password'),
              onTap: _changePassword,
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Dark Theme'),
              value: isDarkTheme,
              onChanged: (bool value) {
                setState(() {
                  isDarkTheme = value;
                });
              },
              activeColor: accentColor,
              inactiveThumbColor: Colors.grey,
              secondary: const Icon(Icons.dark_mode, color: Colors.blueGrey),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Enable Feature X'),
              value: toggleFeature,
              onChanged: (bool value) {
                setState(() {
                  toggleFeature = value;
                });
              },
              activeColor: Colors.orangeAccent,
              inactiveThumbColor: Colors.grey,
              secondary: const Icon(Icons.toggle_on, color: Colors.blueGrey),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Account'),
              onTap: _deleteAccount,
            ),
          ],
        ),
      ),
    );
  }
}
