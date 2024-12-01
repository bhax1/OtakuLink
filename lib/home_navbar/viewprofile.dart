import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:otakulink/main.dart';  // Import to access colors and theme

class ViewProfilePage extends StatefulWidget {
  final String userId;

  const ViewProfilePage({Key? key, required this.userId}) : super(key: key);

  @override
  _ViewProfilePageState createState() => _ViewProfilePageState();
}

class _ViewProfilePageState extends State<ViewProfilePage> {
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentUserId;  // The current user's ID to track the friend request

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _fetchUserProfile() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      setState(() {
        _userProfile = doc.data();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load user profile.';
      });
    }
  }

  // Function to check the friend status
  Future<String> _getFriendRequestStatus() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .collection('friends')
        .doc(widget.userId)
        .get();

    if (snapshot.exists) {
      return snapshot.data()?['status'] ?? 'none';
    } else {
      return 'none';
    }
  }

  // Add friend logic
  void _sendFriendRequest() async {
    FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .collection('friends')
        .doc(widget.userId)
        .set({'status': 'pending'});  // Set the friend request as pending

    setState(() {});
  }

  // Cancel friend request logic
  void _cancelFriendRequest() async {
    FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .collection('friends')
        .doc(widget.userId)
        .delete();  // Remove the pending friend request

    setState(() {});
  }

  // Accept friend request logic
  void _acceptFriendRequest() async {
    // Update the status to 'accepted'
    FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId)
        .collection('friends')
        .doc(widget.userId)
        .update({'status': 'accepted'});

    // Similarly, update the other user's status
    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('friends')
        .doc(_currentUserId)
        .update({'status': 'accepted'});

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: TextStyle(color: textColor)))
              : _userProfile == null
                  ? const Center(child: Text('User profile not found.'))
                  : Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundColor: secondaryColor,
                                  backgroundImage: _userProfile!['photoURL'] != null
                                      ? CachedNetworkImageProvider(_userProfile!['photoURL'])
                                      : null,
                                  child: _userProfile!['photoURL'] == null
                                      ? const Icon(Icons.person, size: 50, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 20),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _userProfile!['username'] ?? 'N/A',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Text(
                                          '${_userProfile!['followersCount'] ?? 0} Followers',
                                          style: TextStyle(fontSize: 14, color: Colors.black54),
                                        ),
                                        const SizedBox(width: 15),
                                        Text(
                                          '${_userProfile!['friendsCount'] ?? 0} Friends',
                                          style: TextStyle(fontSize: 14, color: Colors.black54),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Buttons for Follow and Add Friend
                            FutureBuilder<String>(
                              future: _getFriendRequestStatus(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return CircularProgressIndicator();
                                }

                                final status = snapshot.data;

                                return Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          if (status == 'none') {
                                            _sendFriendRequest();
                                          } else if (status == 'pending') {
                                            _cancelFriendRequest();
                                          } else if (status == 'accepted') {
                                            // You can add additional logic here if needed
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        child: Text(
                                          status == 'none'
                                              ? 'Add Friend'
                                              : status == 'pending'
                                                  ? 'Cancel Request'
                                                  : 'Friends',
                                          style: TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        child: const Text('Follow', style: TextStyle(fontSize: 16)),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 20),

                            // Bio Section (if exists)
                            if (_userProfile!.containsKey('bio')) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Bio: ${_userProfile!['bio']}',
                                style: TextStyle(fontSize: 16, color: textColor),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
    );
  }
}
