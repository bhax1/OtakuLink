import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:otakulink/main.dart';

class UserHeader extends StatelessWidget {
  final FirebaseAuth auth;

  const UserHeader({required this.auth, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser;
    final firestore = FirebaseFirestore.instance;

    if (user == null) {
      return Center(
        child: Text('No user logged in',
            style: TextStyle(fontSize: 18, color: textColor)),
      );
    }

    Future<bool> _isValidImageUrl(String url) async {
      try {
        final response = await http.head(Uri.parse(url));
        final contentType = response.headers['content-type'];
        return contentType != null && contentType.startsWith('image/');
      } catch (_) {
        return false;
      }
    }

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
              cursorColor: accentColor,
              decoration: InputDecoration(
                hintText: 'Enter image URL',
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
                  newPhotoUrl = urlController.text.trim();
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

      if (newPhotoUrl != null && newPhotoUrl!.isNotEmpty) {
        if (await _isValidImageUrl(newPhotoUrl!)) {
          try {
            await user.updatePhotoURL(newPhotoUrl);
            await user.reload();
            firestore.collection('users').doc(user.uid).set(
              {'photoURL': newPhotoUrl},
              SetOptions(merge: true),
            );

            // Show success pop-up dialog
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text('Success'),
                  content: const Text('Profile picture updated successfully!'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK',
                          style: TextStyle(color: Colors.blue)),
                    ),
                  ],
                );
              },
            );
          } catch (e) {
            // Show error pop-up dialog
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text('Error'),
                  content: Text('Failed to update profile picture: $e'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK',
                          style: TextStyle(color: Colors.blue)),
                    ),
                  ],
                );
              },
            );
          }
        } else {
          // Show invalid URL pop-up dialog
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Invalid URL'),
                content: const Text('Invalid image URL. Please try again.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child:
                        const Text('OK', style: TextStyle(color: Colors.blue)),
                  ),
                ],
              );
            },
          );
        }
      }
    }

    Future<void> _editBio(User user) async {
      String? newBio;

      await showDialog(
        context: context,
        builder: (context) {
          TextEditingController bioController = TextEditingController();

          return AlertDialog(
            title: const Text('Edit Bio'),
            content: TextField(
              controller: bioController,
              cursorColor: accentColor,
              decoration: InputDecoration(
                hintText: 'Enter new bio',
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
                  newBio = bioController.text.trim();
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

      if (newBio != null && newBio!.isNotEmpty) {
        try {
          await firestore.collection('users').doc(user.uid).set(
            {'bio': newBio},
            SetOptions(merge: true),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update bio: $e')),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: secondaryColor,
                  backgroundImage: user.photoURL != null
                      ? CachedNetworkImageProvider(user.photoURL!)
                      : null,
                  child: user.photoURL == null
                      ? Icon(Icons.person, size: 50, color: primaryColor)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: IconButton(
                    icon: Icon(Icons.camera_alt, color: backgroundColor),
                    onPressed: () {
                      _updateProfilePicture(user);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: firestore.collection('users').doc(user.uid).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const Text('Error loading data');
                  }
                  if (!snapshot.hasData || snapshot.data!.data() == null) {
                    return const Text('User data not found');
                  }

                  var userData = snapshot.data!.data() as Map<String, dynamic>;
                  int friendsCount = userData['friendsCount'] ?? 0;
                  int followersCount = userData['followersCount'] ?? 0;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCountColumn('Followers', followersCount, textColor),
                      const SizedBox(width: 30),
                      _buildCountColumn('Friends', friendsCount, textColor),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        Column(
          children: [
            const SizedBox(height: 40),
            StreamBuilder<DocumentSnapshot>(
              stream: firestore.collection('users').doc(user.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                if (snapshot.hasError) {
                  return const Text('Error loading data');
                }
                if (!snapshot.hasData || snapshot.data!.data() == null) {
                  return const Text('User data not found');
                }

                var userData = snapshot.data!.data() as Map<String, dynamic>;

                String bio = userData['bio'] ?? 'No bio available';

                return Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            bio,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          _editBio(user);
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit Bio'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: backgroundColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ],
    );
  }

  String formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(count % 1000000 == 0 ? 0 : 1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(count % 1000 == 0 ? 0 : 1)}K';
    } else {
      return count.toString();
    }
  }

  Widget _buildCountColumn(String label, int count, Color textColor) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 20, color: textColor.withOpacity(0.7)),
        ),
        Text(
          formatCount(count), // Use the formatting function
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
