import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:otakulink/main.dart';
import 'package:otakulink/pages/login_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    // Fetch the current user data from FirebaseAuth
    User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Display user's profile picture (or default icon)
            CircleAvatar(
              radius: 50,
              backgroundColor: accentColor,
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!) 
                  : null,
              child: user?.photoURL == null 
                  ? Icon(Icons.person, size: 50, color: Colors.white)
                  : null,
            ),
            SizedBox(height: 20),
            // Display user's name and email
            Text(
              user?.displayName ?? 'User Name', // Default name if null
              style: TextStyle(fontSize: 22, color: textColor),
            ),
            SizedBox(height: 10),
            Text(
              user?.email ?? 'user@example.com', // Default email if null
              style: TextStyle(fontSize: 16, color: textColor),
            ),
            SizedBox(height: 30),
            // Logout button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
              ),
              onPressed: () async {
                await FirebaseAuth.instance.signOut(); // Firebase logout logic
                Navigator.of(context).pushReplacement(PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => LoginScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    const begin = 0.0;
                    const end = 1.0;
                    const curve = Curves.easeInOut;

                    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                    var fadeAnimation = animation.drive(tween);

                    return FadeTransition(opacity: fadeAnimation, child: child);
                  },
                ));
              },
              child: Text('Logout', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}