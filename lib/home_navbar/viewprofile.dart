import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:otakulink/main.dart';
import 'package:otakulink/viewprofile/friend_buttons.dart';
import 'package:otakulink/viewprofile/profile_header.dart';
import 'package:otakulink/viewprofile/profile_service.dart';

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
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  }

  Future<void> _fetchUserProfile() async {
    try {
      final profile = await ProfileService.fetchUserProfile(widget.userId);
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load user profile.';
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
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
              ? Center(child: Text(_errorMessage!))
              : _userProfile == null
                  ? const Center(child: Text('User profile not found.'))
                  : Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          ProfileHeader(userProfile: _userProfile!),
                          const SizedBox(height: 20),
                          Row (
                            children: [
                              FriendButtons(userId: widget.userId, currentUserId: _currentUserId),
                            ],
                          ),
                        ],
                      ),
                    ),
    );
  }
}
