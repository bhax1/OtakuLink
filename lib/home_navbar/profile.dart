import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String username = '';
  String photoURL = '';
  int friendsCount = 0; // Example for friends count
  int followersCount = 0; // Example for followers count

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // Update profile picture
  Future<void> _updateProfilePicture(User user) async {
    String? newPhotoUrl;

    await showDialog(
      context: context,
      builder: (context) {
        TextEditingController urlController = TextEditingController();

        return AlertDialog(
          title: const Text('Update Profile Picture'),
          content: TextField(
            controller: urlController,
            decoration: const InputDecoration(hintText: 'Enter image URL'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                newPhotoUrl = urlController.text.trim();
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newPhotoUrl != null && newPhotoUrl!.isNotEmpty) {
      try {
        await user.updatePhotoURL(newPhotoUrl);
        await user.reload();
        if (mounted) {
          setState(() {});
        }
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'photoURL': newPhotoUrl}, SetOptions(merge: true));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update profile picture: $e')),
          );
        }
      }
    }
  }

  // Load user profile data from Firestore and Hive
  Future<void> _loadUserProfile() async {
    final box = Hive.box('userCache');
    if (mounted) {
      setState(() {
        username = box.get('username', defaultValue: 'Username');
      });
    }

    username = _shortenUsername(username);

    User? currentUser = _auth.currentUser;

    if (currentUser != null) {
      DocumentSnapshot userSnapshot =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (userSnapshot.exists) {
        var userData = userSnapshot.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            photoURL = userData['photoURL'] ?? '';
            friendsCount = userData['friendsCount'] ?? 0;
            followersCount = userData['followersCount'] ?? 0;
          });
        }
      }
    }
  }

  // Function to shorten username if it exceeds 20 characters
  String _shortenUsername(String username) {
    if (username.length > 20) {
      return username.substring(0, 20) + '...'; // Shorten and add ellipsis
    }
    return username;
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;

    return Scaffold(
      body: username.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Profile picture and details in a row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: user?.photoURL != null
                                  ? CachedNetworkImageProvider(user!.photoURL!)
                                  : null,
                              child: user?.photoURL == null
                                  ? const Icon(Icons.person, size: 50, color: Colors.white)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt, color: Colors.white),
                                onPressed: () {
                                  if (user != null) _updateProfilePicture(user);
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Followers and Friends in a row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  // Followers count
                                  Column(
                                    children: [
                                      Text(
                                        'Followers',
                                        style: TextStyle(
                                          fontSize: 20,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      Text(
                                        '$followersCount',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(width: 30),
                                  // Friends count
                                  Column(
                                    children: [
                                      Text(
                                        'Friends',
                                        style: TextStyle(
                                          fontSize: 20,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      Text(
                                        '$friendsCount',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
