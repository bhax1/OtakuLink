import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:otakulink/home_navbar/message.dart';
import 'package:otakulink/home_navbar/viewprofile.dart';
import 'package:otakulink/main.dart';

class FriendsPage extends StatefulWidget {
  @override
  _FriendsPageState createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final TextEditingController _controller = TextEditingController();
  String searchQuery = '';

  Stream<List<Map<String, dynamic>>> _getFriendsStream(String query) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Stream.empty();
    }

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
            'userID': userDoc.data()?['uid'],
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
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: friend['photoURL'] != null
              ? CachedNetworkImageProvider(friend['photoURL'])
              : const AssetImage('assets/pic/default_avatar.png')
                  as ImageProvider,
        ),
        title: Text(friend['username'] ?? 'Unknown User'),
        trailing: IconButton(
          icon: const Icon(Icons.message),
          onPressed: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) {
                  return MessengerPage(friendId: friend['friendDocId']);
                },
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.fastOutSlowIn;
                  var tween = Tween(begin: begin, end: end)
                      .chain(CurveTween(curve: curve));
                  var offsetAnimation = animation.drive(tween);
                  return SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  );
                },
              ),
            );
          },
        ),
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) {
                return ViewProfilePage(userId: friend['friendDocId']);
              },
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.fastOutSlowIn;
                var tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);
                return SlideTransition(
                  position: offsetAnimation,
                  child: child,
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Friends'),
        automaticallyImplyLeading: false,
        backgroundColor: secondaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: FriendSearchDelegate(
                  (query) {
                    setState(() {
                      searchQuery = query;
                    });
                  },
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getFriendsStream(searchQuery),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final friendsList = snapshot.data ?? [];

          if (friendsList.isEmpty) {
            return Center(child: Text('No friends found'));
          }

          return ListView.builder(
            itemCount: friendsList.length,
            itemBuilder: (context, index) {
              return _buildFriendItem(friendsList[index]);
            },
          );
        },
      ),
    );
  }
}

class FriendSearchDelegate extends SearchDelegate {
  final Function(String) onSearch;
  FriendSearchDelegate(this.onSearch);

  @override
  String? get searchFieldLabel => 'Search by username';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          print(query);
          query = '';
          onSearch(query);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    onSearch(query);
    close(context, null);
    return Container();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Container();
  }
}
