import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'message.dart';
import 'pending_request.dart';
import 'viewprofile.dart';
import 'following.dart';
import 'package:otakulink/main.dart';

class FriendsPage extends StatefulWidget {
  @override
  _FriendsPageState createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with AutomaticKeepAliveClientMixin {
  String searchQuery = '';

  @override
  bool get wantKeepAlive => true;

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
    super.build(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: AppBar(
            backgroundColor: Colors.white,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: null,
            bottom: TabBar(
              tabs: const [
                Tab(text: "Friends"),
                Tab(text: "Chats"),
              ],
              indicatorColor: Colors.amber,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
            ),
          ),
        ),
        body: TabBarView(
          children: [
            FriendsTab(
              searchQuery: searchQuery,
              onSearchChanged: _onSearchTextChanged,
              navigateToPage: _navigateToPage,
            ),
            ChatsTab(),
          ],
        ),
      ),
    );
  }
}

/// 🔹 Friends Tab Widget
class FriendsTab extends StatefulWidget {
  final String searchQuery;
  final Function(String) onSearchChanged;
  final void Function(Widget) navigateToPage;

  const FriendsTab({
    required this.searchQuery,
    required this.onSearchChanged,
    required this.navigateToPage,
  });

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab>
    with AutomaticKeepAliveClientMixin {
  final Map<String, Map<String, dynamic>> _userCache = {};

  @override
  bool get wantKeepAlive => true;

  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    if (_userCache.containsKey(userId)) return _userCache[userId];
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final data = doc.data();
    if (data != null) _userCache[userId] = data;
    return data;
  }

  Stream<List<String>> _getFriendIdsStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Stream.empty();

    final sentBy = FirebaseFirestore.instance
        .collection('friends')
        .where('status', isEqualTo: 'friends')
        .where('user1Id', isEqualTo: currentUser.uid)
        .snapshots();

    final receivedBy = FirebaseFirestore.instance
        .collection('friends')
        .where('status', isEqualTo: 'friends')
        .where('user2Id', isEqualTo: currentUser.uid)
        .snapshots();

    return sentBy.asyncExpand((sentSnap) {
      return receivedBy.map((recvSnap) {
        final all = sentSnap.docs + recvSnap.docs;
        return all.map<String>((doc) {
          return doc['user1Id'] == currentUser.uid
              ? doc['user2Id'] as String
              : doc['user1Id'] as String;
        }).toList();
      });
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
        title: Text(friend['username'] ?? 'Unknown User',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ViewProfilePage(userId: friend['friendDocId']),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Row(
          children: [
            PopupMenuButton<int>(
              color: backgroundColor,
              icon: const Icon(Icons.more_horiz),
              onSelected: (int value) {
                switch (value) {
                  case 0:
                    widget.navigateToPage(const PendingRequestsPage());
                    break;
                  case 1:
                    widget.navigateToPage(const FollowingPage());
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<int>(
                  value: 0,
                  child: Row(
                    children: [
                      Icon(Icons.group_add, color: Colors.blueGrey),
                      SizedBox(width: 8),
                      Text('Pending'),
                    ],
                  ),
                ),
                const PopupMenuItem<int>(
                  value: 1,
                  child: Row(
                    children: [
                      Icon(Icons.person_add, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Following'),
                    ],
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  onChanged: widget.onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search friends...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Expanded(
          child: StreamBuilder<List<String>>(
            stream: _getFriendIdsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                // 🔹 Show single centered circular loader
                return const Center(
                  child: CircularProgressIndicator(color: Colors.amber),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("No friends yet"));
              }

              final ids = snapshot.data!;
              final filtered = ids.where((id) {
                final cached = _userCache[id];
                return widget.searchQuery.isEmpty ||
                    (cached?['username'] ?? '')
                        .toLowerCase()
                        .contains(widget.searchQuery.toLowerCase());
              }).toList();

              return RefreshIndicator(
                color: Colors.white,
                backgroundColor: primaryColor,
                onRefresh: () async {
                  setState(() => _userCache.clear());
                },
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final friendId = filtered[index];
                    return FutureBuilder<Map<String, dynamic>?>(
                      future: _getUserData(friendId),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          // Render nothing per item since we show a single loader above
                          return const SizedBox.shrink();
                        }
                        final data = snap.data!;
                        return _buildFriendItem({
                          'friendDocId': friendId,
                          'username': data['username'],
                          'photoURL': data['photoURL'],
                        });
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 🔹 Chats Tab Widget
class ChatsTab extends StatefulWidget {
  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab>
    with AutomaticKeepAliveClientMixin {
  final Map<String, Map<String, dynamic>> _userCache = {};
  String searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    if (_userCache.containsKey(userId)) return _userCache[userId];
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final data = doc.data();
    if (data != null) _userCache[userId] = data;
    return data;
  }

  Stream<List<Map<String, dynamic>>> _getConversationsStream() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.where((doc) => doc.id.contains(currentUser.uid)).toList();
    }).asyncMap((docs) async {
      final results = <Map<String, dynamic>>[];
      for (var doc in docs) {
        final parts = doc.id.split('_');
        if (parts.length < 3) continue;
        final userIds = parts.sublist(1);
        final otherUserId =
            userIds.firstWhere((id) => id != currentUser.uid, orElse: () => '');
        if (otherUserId.isEmpty) continue;

        final data = await _getUserData(otherUserId);
        if (data == null) continue;

        final unreadCounts = doc['unreadCounts'] as Map<String, dynamic>? ?? {};
        final myUnreadCount = unreadCounts[currentUser.uid] ?? 0;

        results.add({
          'friendDocId': otherUserId,
          'username': data['username'],
          'photoURL': data['photoURL'],
          'lastMessage': doc['lastMessage'] ?? '',
          'lastSenderId': doc['lastSenderId'] ?? '',
          'timestamp': doc['timestamp'],
          'unreadCount': myUnreadCount,
        });
      }
      return results;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            onChanged: (val) {
              setState(() => searchQuery = val);
            },
            decoration: InputDecoration(
              hintText: 'Search chats...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getConversationsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.amber));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("No conversations yet"));
              }

              final chats = snapshot.data!;
              final currentUser = FirebaseAuth.instance.currentUser;

              final filteredChats = chats.where((chat) {
                final name = chat['username']?.toLowerCase() ?? '';
                final lastMsg = chat['lastMessage']?.toLowerCase() ?? '';
                final query = searchQuery.toLowerCase();
                return query.isEmpty ||
                    name.contains(query) ||
                    lastMsg.contains(query);
              }).toList();

              if (filteredChats.isEmpty) {
                return const Center(child: Text("No matching chats"));
              }

              return RefreshIndicator(
                color: Colors.white,
                backgroundColor: primaryColor,
                onRefresh: () async {
                  setState(() => _userCache.clear());
                },
                child: ListView.builder(
                  itemCount: filteredChats.length,
                  itemBuilder: (context, index) {
                    final chat = filteredChats[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: chat['photoURL'] != null
                            ? CachedNetworkImageProvider(chat['photoURL'])
                            : const AssetImage('assets/pic/default_avatar.png')
                                as ImageProvider,
                      ),
                      title: Text(chat['username'] ?? 'Unknown'),
                      subtitle: Text(
                        chat['lastSenderId'] == currentUser?.uid
                            ? "You: ${chat['lastMessage']}"
                            : chat['lastMessage'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: chat['unreadCount'] > 0
                          ? CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.red,
                              child: Text(
                                chat['unreadCount'].toString(),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            )
                          : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MessengerPage(
                              friendId: chat['friendDocId'],
                              friendName: chat['username'],
                              friendProfilePic: chat['photoURL'] ?? '',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
