import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:otakulink/main.dart';

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
    if (!confirmReset) return; // Exit if canceled

    // Step 2: Proceed with password change if confirmed
    await showDialog(
      context: context,
      builder: (context) {
        TextEditingController passwordController = TextEditingController();

        return AlertDialog(
          title: const Text('Change Password'),
          content: TextField(
            controller: passwordController,
            cursorColor: accentColor,
            decoration: InputDecoration(
              hintText: 'Enter new password',
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: primaryColor),
              ),
            ),
            obscureText: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: () {
                newPassword = passwordController.text.trim();
                if (newPassword!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password cannot be blank')),
                  );
                } else {
                  Navigator.of(context).pop();
                }
              },
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.blueAccent),
              ),
            ),
          ],
        );
      },
    );

    // If password is null or empty, do not proceed
    if (newPassword == null || newPassword!.isEmpty) return;

    try {
      // Disable interactions by showing a loading dialog
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent interaction outside the dialog
        builder: (context) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.amber),
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
                decoration:
                    const InputDecoration(hintText: 'Enter current password'),
                obscureText: true,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    currentPassword = passwordController.text.trim();
                    if (currentPassword!.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Current password cannot be blank'),
                        ),
                      );
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text(
                    'Authenticate',
                    style: TextStyle(color: Colors.green),
                  ),
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
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                confirmReset = true;
                Navigator.of(context).pop();
              },
              child: const Text('Yes', style: TextStyle(color: Colors.green)),
            ),
          ],
        );
      },
    );
    return confirmReset;
  }

  // Change username logic
  Future<void> _changeUsername() async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    String? newUsername;

    // Show dialog to input new username
    await showDialog(
      context: context,
      builder: (context) {
        TextEditingController usernameController = TextEditingController();

        return AlertDialog(
          title: const Text('Change Username'),
          content: TextField(
            controller: usernameController,
            decoration: InputDecoration(
              hintText: 'Enter new username',
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: primaryColor),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: () {
                newUsername = usernameController.text.trim();
                Navigator.of(context).pop();
              },
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.blueAccent),
              ),
            ),
          ],
        );
      },
    );

    if (newUsername != null && newUsername!.isNotEmpty) {
      try {
        // Disable interactions by showing a loading dialog
        showDialog(
          context: context,
          barrierDismissible: false, // Prevent interaction outside the dialog
          builder: (context) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            );
          },
        );

        FirebaseFirestore firestore = FirebaseFirestore.instance;
        DocumentReference userRef = firestore.collection('users').doc(user.uid);

        // Step 5: Update the username
        await userRef.update({'username': newUsername});

        // Update the username in Hive cache
        final userCache = Hive.box('userCache');
        userCache.put('username', newUsername); // Update the cached username

        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Username updated successfully!'),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update username: $e')),
        );
        // Close the loading dialog in case of an error
        Navigator.of(context).pop();
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
            ListTile(
              leading: const Icon(Icons.account_circle, color: Colors.blue),
              title: const Text('Change Username'),
              onTap: _changeUsername,
            ),
          ],
        ),
      ),
    );
  }
}
