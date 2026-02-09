import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:otakulink/pages/chat/chat_services/user_service.dart';
import 'package:otakulink/pages/profile/viewprofile.dart';
// Import your other pages
import 'pending_request.dart';
import 'following.dart';
import 'chats_tab.dart'; // We will create this next

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  _FriendsPageState createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> with AutomaticKeepAliveClientMixin {
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
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          automaticallyImplyLeading: false,
          elevation: 0,
          title: const TabBar(
            tabs: [
              Tab(text: "Friends"),
              Tab(text: "Chats"),
            ],
            indicatorColor: Colors.amber, // Use primaryColor if available
            labelColor: Colors.blue,      // Use primaryColor if available
            unselectedLabelColor: Colors.grey,
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Friends List
            FriendsTab(
              searchQuery: searchQuery,
              onSearchChanged: _onSearchTextChanged,
              navigateToPage: _navigateToPage,
            ),
            // Tab 2: Optimized Chats
            const ChatsTab(),
          ],
        ),
      ),
    );
  }
}

// --- FRIENDS TAB ---
class FriendsTab extends StatefulWidget {
  final String searchQuery;
  final Function(String) onSearchChanged;
  final void Function(Widget) navigateToPage;

  const FriendsTab({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.navigateToPage,
  });

  @override
  State<FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Stream of Friend IDs
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

    // Combine both streams
    return sentBy.asyncExpand((sentSnap) {
      return receivedBy.map((recvSnap) {
        final allDocs = sentSnap.docs + recvSnap.docs;
        return allDocs.map<String>((doc) {
          return doc['user1Id'] == currentUser.uid
              ? doc['user2Id'] as String
              : doc['user1Id'] as String;
        }).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        // Action Bar & Search
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              PopupMenuButton<int>(
                icon: const Icon(Icons.more_horiz),
                onSelected: (int value) {
                  if (value == 0) widget.navigateToPage(const PendingRequestsPage());
                  if (value == 1) widget.navigateToPage(const FollowingPage());
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 0, child: Row(children: [Icon(Icons.group_add), SizedBox(width: 8), Text('PendingRequests')])),
                  PopupMenuItem(value: 1, child: Row(children: [Icon(Icons.person_add), SizedBox(width: 8), Text('Following')])),
                ],
              ),
              Expanded(
                child: TextField(
                  onChanged: widget.onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search friends...',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Friends List
        Expanded(
          child: StreamBuilder<List<String>>(
            stream: _getFriendIdsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.amber));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("No friends yet"));
              }

              final friendIds = snapshot.data!;

              return RefreshIndicator(
                onRefresh: () async => UserService().clearCache(),
                child: ListView.builder(
                  itemCount: friendIds.length,
                  itemBuilder: (context, index) {
                    final userId = friendIds[index];

                    // Use Shared UserService here!
                    return FutureBuilder<Map<String, dynamic>?>(
                      future: UserService().getUserData(userId),
                      builder: (context, userSnap) {
                        if (!userSnap.hasData) return const SizedBox.shrink(); // Hide until loaded
                        
                        final user = userSnap.data!;
                        final username = user['username'] ?? 'Unknown';
                        
                        // Filter Logic
                        if (widget.searchQuery.isNotEmpty && 
                            !username.toLowerCase().contains(widget.searchQuery.toLowerCase())) {
                          return const SizedBox.shrink();
                        }

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: (user['photoURL'] != null && user['photoURL'] != "")
                                ? CachedNetworkImageProvider(user['photoURL'])
                                : const AssetImage('assets/pic/default_avatar.png') as ImageProvider,
                          ),
                          title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ViewProfilePage(userId: userId)),
                            );
                          },
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