import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:otakulink/main.dart';
import 'message.dart';
import 'pending_request.dart';
import 'viewprofile.dart';
import 'following.dart';

class FriendsPage extends StatefulWidget {
  @override
  _FriendsPageState createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
  }

  Future<void> _refreshFriends() async {
    setState(() {
      searchQuery = '';
    });
  }

  Stream<List<Map<String, dynamic>>> _getFriendsStream(String query) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Stream.empty();

    final sentByStream = FirebaseFirestore.instance
        .collection('friends')
        .where('status', isEqualTo: 'friends')
        .where('user1Id', isEqualTo: currentUser.uid)
        .snapshots();

    final receivedByStream = FirebaseFirestore.instance
        .collection('friends')
        .where('status', isEqualTo: 'friends')
        .where('user2Id', isEqualTo: currentUser.uid)
        .snapshots();

    return sentByStream.asyncExpand((sentBySnapshot) {
      return receivedByStream.map((receivedBySnapshot) {
        final allDocs = sentBySnapshot.docs + receivedBySnapshot.docs;

        final futures = allDocs.map((doc) async {
          final friendId = doc['user1Id'] == currentUser.uid
              ? doc['user2Id']
              : doc['user1Id'];
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(friendId)
              .get();
          return {
            'friendDocId': userDoc.id,
            'username': userDoc.data()?['username'],
            'photoURL': userDoc.data()?['photoURL'],
          };
        });

        return Future.wait(futures);
      });
    }).asyncMap((futureFriendsList) async {
      final friends = await futureFriendsList;
      if (query.isNotEmpty) {
        return friends
            .where((friend) =>
                friend['username']?.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
      return friends;
    });
  }

  Widget _buildFriendItem(Map<String, dynamic> friend) {
    return Card(
      color: backgroundColor,
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: friend['photoURL'] != null
              ? CachedNetworkImageProvider(friend['photoURL'])
              : const AssetImage('assets/pic/default_avatar.png')
                  as ImageProvider,
        ),
        title: Text(
          friend['username'] ?? 'Unknown User',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.message),
          onPressed: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => MessengerPage(
                  friendId: friend['friendDocId'],
                  friendName: friend['username'],
                  friendProfilePic: friend['photoURL'] ?? '',
                ),
                transitionsBuilder: (_, animation, __, child) {
                  const offsetStart = Offset(1.0, 0.0);
                  const offsetEnd = Offset.zero;
                  const curve = Curves.fastOutSlowIn;
                  var tween = Tween(begin: offsetStart, end: offsetEnd)
                      .chain(CurveTween(curve: curve));
                  return SlideTransition(
                      position: animation.drive(tween), child: child);
                },
              ),
            );
          },
        ),
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) =>
                  ViewProfilePage(userId: friend['friendDocId']),
              transitionsBuilder: (_, animation, __, child) {
                const offsetStart = Offset(1.0, 0.0);
                const offsetEnd = Offset.zero;
                const curve = Curves.fastOutSlowIn;
                var tween = Tween(begin: offsetStart, end: offsetEnd)
                    .chain(CurveTween(curve: curve));
                return SlideTransition(
                    position: animation.drive(tween), child: child);
              },
            ),
          );
        },
      ),
    );
  }

  void _onSearchTextChanged(String text) {
    setState(() {
      searchQuery = text;
    });
  }

  void _navigateToPage(Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.fastOutSlowIn;
          final tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
              position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior:
            HitTestBehavior.translucent,
        onTap: () {
          _focusNode.unfocus();
        },
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                PopupMenuButton<int>(
                  color: backgroundColor,
                  icon: const Icon(
                    Icons.more_horiz,
                  ),
                  onSelected: (int value) {
                    switch (value) {
                      case 0:
                        _navigateToPage(const PendingRequestsPage());
                        break;
                      case 1:
                        _navigateToPage(const FollowingPage());
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<int>(
                      value: 0,
                      child: Row(
                        children: const [
                          Icon(
                            Icons.group_add,
                            color: Colors.blueGrey,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Pending',
                            style: TextStyle(color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<int>(
                      value: 1,
                      child: Row(
                        children: const [
                          Icon(
                            Icons.person_add,
                            color: Colors.blue,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Following',
                            style: TextStyle(color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: _onSearchTextChanged,
                      cursorColor: accentColor,
                      decoration: InputDecoration(
                        hintText: 'Search friends...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: RefreshIndicator(
                color: backgroundColor,
                backgroundColor: primaryColor,
                onRefresh: _refreshFriends,
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _getFriendsStream(searchQuery),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                          child:
                              CircularProgressIndicator(color: Colors.amber));
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final friendsList = snapshot.data ?? [];

                    final filteredFriends = friendsList.where((friend) {
                      return friend['username']
                          .toLowerCase()
                          .contains(searchQuery.toLowerCase());
                    }).toList();

                    return ListView.builder(
                      itemCount: filteredFriends.length,
                      itemBuilder: (context, index) {
                        return _buildFriendItem(filteredFriends[index]);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
