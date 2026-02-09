import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:otakulink/theme.dart';

class UserHeader extends StatelessWidget {
  final FirebaseAuth auth;

  const UserHeader({required this.auth, Key? key}) : super(key: key);

  // --- LOGIC HELPER METHODS ---

  Future<bool> _isValidImageUrl(String url) async {
    if (url.isEmpty) return false;
    try {
      final response = await http.head(Uri.parse(url));
      final contentType = response.headers['content-type'];
      return contentType != null && contentType.startsWith('image/');
    } catch (_) {
      return false;
    }
  }

  Future<void> _updateProfilePicture(BuildContext context, User user) async {
    String? newPhotoUrl;
    final TextEditingController urlController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Profile Picture'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Enter a direct link to an image (URL)"),
              const SizedBox(height: 10),
              TextField(
                controller: urlController,
                cursorColor: AppColors.accent,
                decoration: InputDecoration(
                  hintText: 'https://example.com/image.jpg',
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                newPhotoUrl = urlController.text.trim();
                Navigator.of(context).pop();
              },
              child: const Text('Save', style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        );
      },
    );

    if (newPhotoUrl != null && newPhotoUrl!.isNotEmpty) {
      // Validate URL before saving
      bool isValid = await _isValidImageUrl(newPhotoUrl!);
      
      if (isValid) {
        try {
          // 1. Update Auth Profile
          await user.updatePhotoURL(newPhotoUrl);
          await user.reload();
          
          // 2. Update Firestore
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
            {'photoURL': newPhotoUrl},
            SetOptions(merge: true),
          );

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Profile picture updated!")),
            );
          }
        } catch (e) {
          _showError(context, "Failed to update: $e");
        }
      } else {
        _showError(context, "Invalid Image URL. Please ensure the link ends in .jpg or .png");
      }
    }
  }

  Future<void> _editBio(BuildContext context, User user, String currentBio) async {
    String? newBio;
    final TextEditingController bioController = TextEditingController(text: currentBio);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Bio'),
          content: TextField(
            controller: bioController,
            maxLines: 3,
            cursorColor: AppColors.accent,
            decoration: InputDecoration(
              hintText: 'Tell us about yourself...',
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                newBio = bioController.text.trim();
                Navigator.of(context).pop();
              },
              child: const Text('Save', style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        );
      },
    );

    if (newBio != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {'bio': newBio},
          SetOptions(merge: true),
        );
      } catch (e) {
        _showError(context, "Failed to save bio");
      }
    }
  }

  void _showError(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser;
    final firestore = FirebaseFirestore.instance;

    if (user == null) return const SizedBox.shrink();

    return Column(
      children: [
        // 1. TOP SECTION (Avatar + Stats)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar with Edit Button
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2), // Ring effect
                    ),
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: (user.photoURL != null && user.photoURL!.isNotEmpty)
                          ? CachedNetworkImageProvider(user.photoURL!)
                          : null,
                      child: (user.photoURL == null || user.photoURL!.isEmpty)
                          ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: () => _updateProfilePicture(context, user),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(width: 25),

              // Stats Row (Streamed)
              Expanded(
                child: StreamBuilder<DocumentSnapshot>(
                  stream: firestore.collection('users').doc(user.uid).snapshots(),
                  builder: (context, snapshot) {
                    int friends = 0;
                    int followers = 0;
                    
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>;
                      friends = data['friendsCount'] ?? 0;
                      followers = data['followersCount'] ?? 0;
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem('Followers', followers),
                        Container(height: 30, width: 1, color: Colors.grey[300]), // Divider
                        _buildStatItem('Friends', friends),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 25),

        // 2. BIO SECTION
        StreamBuilder<DocumentSnapshot>(
          stream: firestore.collection('users').doc(user.uid).snapshots(),
          builder: (context, snapshot) {
            String bio = 'No bio yet.';
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              bio = data['bio'] ?? 'No bio yet.';
            }

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    bio,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      fontStyle: bio == 'No bio yet.' ? FontStyle.italic : FontStyle.normal,
                      color: Colors.grey[800],
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed: () => _editBio(context, user, bio),
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('Edit Bio', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  )
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Column(
      children: [
        Text(
          _formatCount(count),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}