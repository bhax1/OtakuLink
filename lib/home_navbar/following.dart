import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:otakulink/home_navbar/viewprofile.dart';
import 'package:otakulink/main.dart';

class FollowingPage extends StatefulWidget {
  const FollowingPage({super.key});

  @override
  _FollowingPageState createState() => _FollowingPageState();
}

class _FollowingPageState extends State<FollowingPage> {
  String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  String _sortOption = 'name';
  String _sortOrder = 'asc';
  String _searchQuery = '';
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: backgroundColor,
        title: _buildSearchField(),
        actions: [_buildFilterButton()],
      ),
      body: GestureDetector(
        onTap: () => _focusNode.unfocus(),
        child: RefreshIndicator(
          color: backgroundColor,
          backgroundColor: primaryColor,
          onRefresh: () async => setState(() {}),
          child: _buildFollowingList(),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).requestFocus(_focusNode),
      child: TextField(
        focusNode: _focusNode,
        cursorColor: accentColor,
        decoration: const InputDecoration(
          hintText: 'Search by username...',
          border: InputBorder.none,
          hintStyle: TextStyle(color: Colors.white70),
        ),
        style: const TextStyle(color: Colors.white),
        onChanged: (value) =>
            setState(() => _searchQuery = value.toLowerCase()),
      ),
    );
  }

  Widget _buildFilterButton() {
    return IconButton(
      icon: Icon(Icons.filter_list, color: backgroundColor),
      onPressed: () => _showSortBottomSheet(context),
    );
  }

  Widget _buildFollowingList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('following')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.amber),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.data?.docs.isEmpty ?? true) {
          return const Center(child: Text('You are not following anyone.'));
        }

        final followingList = snapshot.data!.docs;

        // We fetch the details of the following users here
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchFollowingDetails(followingList),
          builder: (context, followingDetailsSnapshot) {
            if (followingDetailsSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.amber));
            }

            if (followingDetailsSnapshot.hasError) {
              return Center(
                  child: Text('Error: ${followingDetailsSnapshot.error}'));
            }

            var followingDetails = followingDetailsSnapshot.data ?? [];
            followingDetails = _applyFilters(followingDetails);

            // Using ListView.separated for a cleaner UI
            return ListView.separated(
              itemCount: followingDetails.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) =>
                  _buildFollowingTile(followingDetails[index]),
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> _applyFilters(
      List<Map<String, dynamic>> followingDetails) {
    followingDetails.sort((a, b) {
      int comparison;
      if (_sortOption == 'name') {
        comparison = (a['username'] ?? '').compareTo(b['username'] ?? '');
      } else if (_sortOption == 'followers') {
        comparison =
            (b['followersCount'] ?? 0).compareTo(a['followersCount'] ?? 0);
      } else {
        final aTimestamp = a['timestamp'] as Timestamp?;
        final bTimestamp = b['timestamp'] as Timestamp?;
        comparison = (aTimestamp?.compareTo(bTimestamp!) ?? 0);
      }
      return _sortOrder == 'desc' ? -comparison : comparison;
    });

    if (_searchQuery.isNotEmpty) {
      followingDetails = followingDetails
          .where((user) =>
              (user['username'] ?? '').toLowerCase().contains(_searchQuery))
          .toList();
    }
    return followingDetails;
  }

  Widget _buildFollowingTile(Map<String, dynamic> userData) {
    return ListTile(
      leading: GestureDetector(
        onTap: () => Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
                ViewProfilePage(userId: userData['id']),
            transitionsBuilder: (_, animation, __, child) {
              return SlideTransition(
                position: animation.drive(Tween(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).chain(CurveTween(curve: Curves.fastOutSlowIn))),
                child: child,
              );
            },
          ),
        ),
        child: CircleAvatar(
          backgroundImage: userData['photoURL'] != null
              ? CachedNetworkImageProvider(userData['photoURL'])
              : const AssetImage('assets/pic/default_avatar.png')
                  as ImageProvider,
        ),
      ),
      title: Text(
        userData['username'] ?? 'Unknown User',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${formatCount(userData['followersCount'] ?? 0)} ${userData['followersCount'] == 1 ? "follower" : "followers"}',
      ),
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

  Future<List<Map<String, dynamic>>> _fetchFollowingDetails(
      List<QueryDocumentSnapshot> followingList) async {
    return Future.wait(followingList.map((doc) async {
      final followedId = doc['followedId'];
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(followedId)
          .get();

      if (userSnapshot.exists) {
        return {
          'id': followedId,
          'username': userSnapshot.data()?['username'] ?? 'Unknown User',
          'photoURL': userSnapshot.data()?['photoURL'],
          'followersCount': userSnapshot.data()?['followersCount'] ?? 0,
          'timestamp': doc['timestamp'],
        };
      }
      return {}; // Return an empty map if user data doesn't exist
    }));
  }

  void _showSortBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sort By', style: Theme.of(context).textTheme.titleLarge),
            _buildSortOption('Name', 'name'),
            _buildSortOption('Followers', 'followers'),
            _buildSortOption('Date Followed', 'date'),
            const Divider(),
            Text('Order', style: Theme.of(context).textTheme.titleLarge),
            _buildSortOrder('Ascending', 'asc'),
            _buildSortOrder('Descending', 'desc'),
          ],
        ),
      ),
    );
  }

  ListTile _buildSortOption(String title, String value) {
    return ListTile(
      title: Text(title),
      leading: Radio<String>(
        activeColor: accentColor,
        value: value,
        groupValue: _sortOption,
        onChanged: (newValue) => _updateSortOption(newValue),
      ),
    );
  }

  ListTile _buildSortOrder(String title, String value) {
    return ListTile(
      title: Text(title),
      leading: Radio<String>(
        activeColor: accentColor,
        value: value,
        groupValue: _sortOrder,
        onChanged: (newValue) => _updateSortOrder(newValue),
      ),
    );
  }

  void _updateSortOption(String? newValue) {
    setState(() => _sortOption = newValue!);
    Navigator.pop(context);
  }

  void _updateSortOrder(String? newValue) {
    setState(() => _sortOrder = newValue!);
    Navigator.pop(context);
  }
}
